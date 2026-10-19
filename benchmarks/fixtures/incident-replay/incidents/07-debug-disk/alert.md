# SearchAvailability — page

Fired:    2026-05-12T13:22:00Z (search 5xx ratio above 6 x budget, 6h/30m)
Service:  search-api (Python 3.12, gunicorn) on Kubernetes, 10 pods
Symptom:  pods evicted every ~40 min, capacity drops, 503s at the ingress
Scope:    all users, waves of 5-10 minutes
