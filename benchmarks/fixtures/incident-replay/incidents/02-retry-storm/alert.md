# PaymentsCaptureFailures — page

Fired:    2026-09-03T14:04:00Z (capture error ratio above 14.4 x budget, 1h/5m)
Service:  payments-api (Node 22, NestJS), outbound to the card provider
Symptom:  capture failures 0.1 % -> 63 % from 14:02; provider answers 503, then 429
Scope:    all merchants
Recovered: 14:28 after the provider raised our rate limit and traffic was shed at the gateway
