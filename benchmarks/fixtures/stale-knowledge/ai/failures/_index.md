# Failures

Approaches that were tried and failed, so nobody tries them again. One entry per attempt; themes repeat by heading.

## Format per entry

```
### YYYY-MM-DD — <short label for the failed approach>
Status: ACTIVE | RESOLVED | SUPERSEDED
Where: `path:line`
What to do instead: <the alternative>
```

## Entries

### 2026-07-21 — reset the shared staging database by script
Status: ACTIVE
Where: `docker-compose.yml:3`
What to do instead: never run a reset script against staging or production; one wipe lost a day of QA data.

### 2026-07-29 — report totals from a read replica
Status: ACTIVE
Where: `apps/api/src/modules/reports/reports.service.ts:11`
What to do instead: read month-end totals from the primary; replica lag skewed them.

### 2026-08-01 — inline SQL for the monthly report
Status: ACTIVE
Where: `apps/api/src/modules/reports/reports.service.ts:12`
What to do instead: keep the query in the reports service with bound parameters; string-built SQL broke on quotes.

### 2026-08-08 — webhook retries stormed the payment provider
Status: ACTIVE
Where: `apps/api/src/modules/webhooks/webhooks.service.ts:12`
What to do instead: cap attempts at five with exponential backoff.

### 2026-08-21 — capture retried inside the request
Status: ACTIVE
Where: `apps/api/src/modules/payments/payments.service.ts:140`
What to do instead: record the capture attempt and let the queue retry it.

### 2026-09-10 — webhook retries stormed the payment provider
Status: ACTIVE
Where: `apps/api/src/modules/webhooks/webhooks.service.ts:12`
What to do instead: the same storm after the refunds release; the cap had been removed.

### 2026-09-18 — always page report exports
Status: ACTIVE
Where: `apps/api/src/modules/reports/reports.service.ts:11`
What to do instead: always stream report exports in pages of 500 rows.

### 2026-09-24 — a migration locked the order table
Status: ACTIVE
Where: `apps/api/src/migrations/Migration20260924.ts:5`, `apps/api/src/migrations/Migration20260920.ts:5`
What to do instead: always set `lock_timeout` before an index or column change on the order table.
