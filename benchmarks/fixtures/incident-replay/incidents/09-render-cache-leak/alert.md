# StorefrontRestarts — ticket, then page

Fired:    2026-03-17T16:40:00Z (restarts > 3 per pod per hour)
Service:  storefront SSR (Node 22, Express), 12 pods, memory limit 1.5Gi
Symptom:  OOMKilled every ~90 min since 11:00; brief 502s on each kill
Context:  a marketing campaign went out at 10:55 with tracked links
