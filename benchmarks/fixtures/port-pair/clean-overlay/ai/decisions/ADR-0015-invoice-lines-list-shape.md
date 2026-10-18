# ADR-0015 — Invoice `lines` is always a JSON list

Status: Accepted

V1 filtered zero-quantity lines with `array_filter` and no `array_values`, so an invoice with a
zero line serialised `lines` as an object keyed by position. V2 returns a list. Every client
already handled the list shape. `changes_baseline: ["invoices.lines-shape"]`.
