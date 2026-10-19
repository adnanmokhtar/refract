# RenewalDoubleCharge — page (raised by finance)

Fired:    2026-02-02T07:45:00Z (two successful renewal charges for one subscription period)
Service:  billing-jobs (Python 3.12, Kubernetes CronJob `charge-renewals`)
Symptom:  1,140 subscriptions charged twice between 06:00 and 07:30
Context:  the renewals job was refactored and deployed on 2026-02-01; the subscriber base grew 30 % in January
