# ADR 0011 — Inventory reservation latency is ticket-only

Status: accepted (2026-02-17)

Reservations are retried by the checkout, and a slow reservation costs seconds, not orders. The latency objective
(99 % under 200 ms over 30 days) is watched with the two slow burn tiers only (3× over 1d/2h, 1× over 3d/6h), both
tickets for the inventory team. Nobody is paged for it.
