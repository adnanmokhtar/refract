# Drift log

Divergences between what the knowledge layer says and what the code does. One entry per divergence. When the code or
the document is fixed, the heading gets `RESOLVED` and the fixing commit; entries are never deleted.

## Format per entry

```
### YYYY-MM-DD — <area>: <what diverged>
- **Where:** `path:line`
- **Drift:** <the document says X; the code does Y>
- **Severity:** low | high
```

## Entries

### 2026-07-30 — RESOLVED docs: deploy runbook named the manual image build
- **Where:** `docs/runbooks/deploy.md:2`
- **Drift:** the runbook described a manual build; deploys moved to CI. Resolved by removing the runbook (2026-08-31).
- **Severity:** low

### 2026-08-11 — api: tenant filter registration
- **Where:** `apps/api/src/shared/tenancy/tenant.filter.ts:20`
- **Drift:** the architecture page says the filter is registered per module; it is global middleware.
- **Severity:** low

### 2026-08-18 — web: list screens without an empty state
- **Where:** `apps/web/src/features/orders/OrdersPage.tsx:6`
- **Drift:** the web rules ask for an empty state; the orders screen renders an empty table.
- **Severity:** low

### 2026-08-25 — api: discounts still described as coupons
- **Where:** `apps/api/src/modules/coupons/coupons.service.ts:9`
- **Drift:** the modules table describes coupon codes; the code applies discounts per order line.
- **Severity:** high

### 2026-09-09 — api: error mapping in reports
- **Where:** `apps/api/src/modules/reports/reports.service.ts:17`
- **Drift:** the reports service raises a domain error while its neighbours raise Nest exceptions.
- **Severity:** low
