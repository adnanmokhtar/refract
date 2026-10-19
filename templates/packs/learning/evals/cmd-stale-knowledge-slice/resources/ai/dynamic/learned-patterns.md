# Learned patterns

Patterns seen in three or more files. READY patterns older than two weeks are promoted into `ai/patterns/`.

## Format per entry

```
### YYYY-MM-DD — <pattern name>
- Status: WATCHING | READY | PROMOTED | REJECTED
- Files: `path:line` (one per occurrence)
- Description: <one or two sentences>
```

## Entries

### 2026-09-12 — idempotency key on every POST handler
- Status: READY
- Files: `apps/api/src/modules/orders/orders.controller.ts:25`, `apps/api/src/modules/refunds/refunds.controller.ts:9`, `apps/api/src/modules/webhooks/webhooks.service.ts:10`
- Description: POST handlers accept an idempotency key header and replay the stored response for a repeated key.

### 2026-10-01 — query hooks wrap the api client
- Status: WATCHING
- Files: `apps/web/src/features/orders/useOrders.ts:5`
- Description: every server read in the web app is a query hook over the shared client.
