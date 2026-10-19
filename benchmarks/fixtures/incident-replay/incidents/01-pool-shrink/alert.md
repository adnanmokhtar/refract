# CheckoutFastBurn — page

Fired:    2026-10-19T09:15:00Z (expr: checkout error ratio 1h and 5m above 14.4 x budget)
Service:  checkout (Rails 7.2, Puma, 6 pods), Postgres 16 primary
Symptom:  POST /orders 5xx ratio 0.04 % -> 8.8 % from 09:12; p99 latency 380 ms -> 2.1 s
Scope:    every pod, every tenant
Recovered: 09:41 after `/rollback-deploy --env=production --to=rev 57`
