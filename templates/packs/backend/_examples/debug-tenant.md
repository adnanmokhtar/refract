---
name: debug-tenant
description: Debug tenant isolation issues — a user sees data that doesn't belong to them, or doesn't see data that does. Multi-step playbook that walks the full tenant-resolution chain.
---

# debug-tenant

## When to invoke

- Customer reports: "I see products I don't own" / "my orders are missing"
- Audit finds cross-tenant data in a response
- Cache returns data from tenant B to tenant A

## Steps

### 1. Reproduce
- Get the request: correlation id + tenant id + user id + endpoint.
- If reproducible in staging, continue. If not, pull logs.

### 2. Trace tenant resolution
Walk the chain — each step shows what was passed vs what was expected:

```
Request arrives:
  Host:              <header>        → resolved to tenant? <id or NULL>
  X-Product-Id:      <header>        → override applied? <yes/no>
  X-API-Key:         <header>        → resolved to tenant? <id or NULL>
  Domain:            <domain>        → matched tenants.domain? <id or NULL>

TenantResolutionMiddleware:
  Resolved tenant:   <id>
  Written to:        AsyncLocalStorage ✓
```

### 3. Trace query scope
For the endpoint that leaked:

```
Controller:  reads TenantContext.get() → <id> ✓
Service:     does NOT pass tenantId around ✓
Repository:  base class adds WHERE tenant_id = :tenantId ✓
Actual SQL:  [dump the query] → does it have tenant_id filter?
```

If the SQL lacks the filter — that's the bug.

### 4. Trace cache
If the response was cached:

```
Cache key:  tenant:<id>:<namespace>:<key> ✓  OR  <namespace>:<key> ← LEAK
```

If key isn't tenant-prefixed → that's the bug.

### 5. Event replay
If the data came from an event handler:

```
Event received:      pattern=<x>  metadata.tenant=<id>  payload=<ids>
Handler scoped to:   TenantContext.run(metadata.tenant, ...) ✓
Downstream query:    WHERE tenant_id = :tenantId ✓
```

## Output

```
TENANT LEAK — ROOT CAUSE IDENTIFIED

Request:       GET /reports/daily  tenant=A  correlation=abc-123
Leaked data:   3 orders from tenant B

Root cause:
  src/modules/reports/infrastructure/reports.repository.impl.ts:84
  Raw SQL bypasses base repo:
    SELECT * FROM orders WHERE created_at >= $1
  Missing:
    AND tenant_id = $2

Fix:
  Use this.scope(qb) OR add explicit tenant filter to raw query.

Similar bugs to check:
  grep "SELECT .* FROM orders" src/modules/reports/**/*.ts
```

## Rules

- Never paper over with a "temporary fix" — tenant leaks are security incidents.
- File an incident write-up in `ai/audits/` after root cause is known.
- Add a regression test that would have caught this BEFORE shipping the fix.
