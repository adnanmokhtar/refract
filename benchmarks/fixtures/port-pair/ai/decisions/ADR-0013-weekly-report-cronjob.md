# ADR-0013 — The weekly sales report runs as a Kubernetes CronJob

Status: Accepted (2026-09-15)

V1 dispatched `SendWeeklyReport` from the scheduler (Sundays 07:00 Asia/Riyadh). V2 runs the same
job as `deploy/k8s/cronjobs/weekly-report.yaml` with `timeZone: Asia/Riyadh` (and, as in V1, no
overlap guard: a weekly run cannot overlap itself), so it is not in the API's `@Cron` registry.
