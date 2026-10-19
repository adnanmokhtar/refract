# OrdersDuplicateRate — ticket escalated to page

Fired:    2026-04-08T19:12:00Z (orders sharing (customer, cart) within 60 s above threshold)
Service:  edge gateway (Envoy) -> orders-api (Java 21) -> payment provider
Symptom:  1.8 % of orders created twice; customers charged twice; provider latency elevated 19:05-19:40
Scope:    orders whose payment call took longer than ~5 s
