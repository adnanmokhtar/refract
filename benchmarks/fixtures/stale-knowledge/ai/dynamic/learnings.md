# Learnings

Raw observations from sessions. Three sightings with two cited examples promote an entry into `ai/conventions.md`.

## Format per entry

```
### YYYY-MM-DD — <short observation>
Status: RAW | PROMOTE_CANDIDATE | PROMOTED | DISCARDED
Source: `path:line` (one per sighting)
```

## Entries

### 2026-08-05 — dates leave the API as ISO strings
Status: RAW
Source: `.claude/rules/legacy-dates.md:4`, `packages/contracts/src/index.ts:5`
Dates are serialised in the contracts as ISO 8601 strings with an offset.

### 2026-08-12 — flush once at the end of a use case
Status: RAW
Source: `apps/api/src/modules/orders/application/place-order.use-case.ts:17`, `apps/api/src/modules/orders/orders.service.ts:27`
Always call `em.flush()` once, at the end of the use case, so a failure leaves nothing half-written.

### 2026-09-02 — never open transactions in read handlers
Status: RAW
Source: `apps/api/src/modules/reports/reports.service.ts:11`
A report query held a transaction open for minutes during month-end. Never use transactions in read handlers.

### 2026-09-09 — axios stays inside the api client
Status: RAW
Source: `apps/web/src/features/orders/useOrders.ts:3`, `apps/web/src/lib/apiClient.ts:1`
Never import `axios` directly in a feature; call the shared api client instead.

### 2026-09-16 — flush inside each repository save
Status: RAW
Source: `apps/api/src/shared/persistence/base.repository.ts:6`, `apps/api/src/modules/refunds/refunds.service.ts:12`
Never defer `em.flush()` to the end of a use case; flush inside `save()` so ids exist right away.

### Retry webhook deliveries with jitter
Status: RAW
Source: `apps/api/src/modules/webhooks/webhooks.service.ts:12`
Deliveries retried on a fixed backoff hit the receiver in waves; jitter spreads them.
