---
name: debug-tenant
description: Debug tenant isolation issues — a user sees data that doesn't belong to them, or doesn't see data that does. Use on a suspected cross-tenant leak or a missing-data report; walks the full tenant-resolution chain hop by hop. Not a static scan — it reproduces against a running system via `log-tail` and `endpoint-test`.
---

# debug-tenant

## Premise

Find the real leak, not a plausible one. Every step cites the actual value observed (header, resolved id, SQL, cache key) at `<file:line>`. "Probably the cache" is not a root cause. The chain — host → middleware → context → repo → SQL → cache — must be walked top-to-bottom; skipping a step on a guess is forbidden. Tenant leaks are security incidents and the report must name the file:line that produced the leaked SQL or cache key.

A "fixed" leak without a regression test that would have caught it is unfinished work.

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

## Related

- `.claude/skills/log-tail/SKILL.md` — the tracing primitive for steps 2–5: filter by correlation id / tenant id to observe the resolved id, SQL, and cache key at each hop.
- `.claude/skills/endpoint-test/SKILL.md` — reproduces the leak deterministically (case 4, wrong tenant) and confirms the fix; a cross-tenant 200 there is the same finding.
- Used by `@bug-investigator` — this playbook is the tenant-isolation branch of that agent's root-cause search.
- `ai/patterns/multi-tenancy.md` — the tenant-resolution + query-scoping contract the chain (host → middleware → context → repo → SQL → cache) walks.
- `ai/patterns/caching-strategy.md` — the tenant-prefixed, versioned cache-key rule whose violation is the step-4 leak.
- `.claude/rules/backend-principles.md` — the tenant-isolation MUSTs behind "a leak is a security incident".

## Halt conditions

- Halt on hand-waves: every root-cause claim must cite `<file:line>` + the actual SQL or cache key produced.
- Halt if a step in the chain (host → middleware → context → repo → SQL → cache) was skipped without a recorded reason.
- Halt if the fix ships without a regression test that fails on the unfixed code path.
- Halt if the incident write-up is deferred — `ai/audits/` entry is part of "done", not an after-task.
