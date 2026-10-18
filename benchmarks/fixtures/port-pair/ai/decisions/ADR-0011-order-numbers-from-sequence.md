# ADR-0011 — Order numbers come from a database sequence

Status: Accepted (2026-09-10)

V1 computed `SO-` + `max(id) + 1` inside the placement transaction, so two concurrent placements
could compute the same number and one failed on the unique index with a 500 (contract
orders.md KB-1). V2 takes `nextval('order_number_seq')`. Numbers stay `SO-` + 7 digits; gaps are
now possible. `changes_baseline: ["orders.number-source"]`.
