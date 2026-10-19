# CheckoutWriteLatency — page

Fired:    2026-07-14T08:33:00Z (orders write p99 above SLO threshold, fast burn)
Service:  checkout (Rails 7.1) on Postgres 15, orders table ~41M rows
Symptom:  INSERT/UPDATE on orders time out (statement_timeout 5s); reads fine
Scope:    every write path that touches orders
Recovered: 08:43 without intervention
