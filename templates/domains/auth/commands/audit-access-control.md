---
description: Audit every endpoint for broken access control — enumerate endpoint × who-can-call-it × the ownership / tenant-scope check, citing the call site for each. Catches IDOR, missing guards, and client-only authorization.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /audit-access-control

Map the project's real authorization surface and prove — per endpoint — that access is gated server-side and every object access is scoped to its owner / tenant. This is an IDOR / authorization-coverage audit, not a vibe check.

## Premise

Real signals only. Cite the actual route declaration, the actual guard / policy call, and the actual ownership predicate (the `WHERE id AND tenant_id`) — each at `<path:line>`. "Looks protected" without the file is noise. The verdict for each endpoint comes from reading the route handler + its query, not the route's name or its JSDoc. A hidden button / disabled menu item is NOT access control and is never counted as a check.

## Mechanical halt

**Cite-or-halt.** Every row in the matrix MUST carry three citations or it is a finding, not a pass:
1. the route declaration `<path:line>`,
2. the authorization check `<path:line>` (guard / `can()` / policy) OR an explicit `@Public()` declaration,
3. the ownership / tenant-scope predicate `<path:line>` for any handler that loads a resource by a client-supplied id.

An endpoint that loads `:id` (or any client-supplied identifier) and cannot cite an ownership predicate is reported as **BLOCKER — IDOR**, never quietly passed. Halt the audit (refuse a clean verdict) if:
- the session strategy ADR (`ai/decisions/auth-session-strategy.md`) is missing — request it first;
- no central authorization primitive (guard / `can()` / policy) can be located — request it before auditing, since per-endpoint inline checks cannot be audited for coverage reliably.

## Pre-flight

- Read `ai/patterns/auth-architecture.md` + `.claude/rules/auth-discipline.md`.
- Locate the central guard / policy (`can(actor, action, resource)` / middleware) and how `@Public()` / public routes are marked.
- Identify the tenant / ownership column(s): `tenant_id`, `org_id`, `owner_id`, `user_id`.
- Identify the route framework so the route inventory is exhaustive (decorators, a router file, an OpenAPI spec, file-based routing).

## Flow

1. **Enumerate every route.** Grep all HTTP method decorators / router registrations / file-based routes. Build the full list — missing a route is the most common audit failure. Cross-check against the OpenAPI spec if one exists.
2. **Classify each route's intended audience.** public / authenticated-any / role-restricted / owner-or-tenant-scoped / admin. Derive from the guard + policy, not the path name.
3. **Locate the authorization check** for each route: the guard annotation, the `can()` call, or an explicit `@Public()`. Cite `<path:line>`.
4. **For every route that loads a resource by a client-supplied id**, locate the ownership / tenant-scope predicate in the query. Cite `<path:line>`. No predicate → IDOR finding.
5. **Check for mass-assignment** of `role` / `tenant_id` / `is_admin` from request bodies on create/update routes. Cite the DTO / binding.
6. **Cross-check client-only gates.** For any UI route guard / hidden control, confirm the corresponding API endpoint independently re-enforces. Client-only = BLOCKER.
7. **Emit the matrix + findings.** One row per endpoint; one finding per gap with impact + fix.

## Output

```
/audit-access-control — <scope>

Coverage: <N endpoints>  protected=<n>  public(declared)=<n>  UNGATED=<n>  IDOR=<n>

Matrix:
  METHOD  PATH                  audience            authz@                 ownership-scope@
  GET     /invoices/:id         tenant-scoped       guard invoice.ctrl:16  repo.findScoped invoice.repo:40
  POST    /admin/users          admin               can() user.ctrl:22     n/a (create)
  DELETE  /users/:id            admin               MISSING                 MISSING            ← BLOCKER
  GET     /public/health        public(@Public)     n/a                     n/a

BLOCKERS (N):
  - <METHOD PATH> — <IDOR | ungated | client-only authz> at <path:line>
    Impact: <who reads/writes what they shouldn't>
    Fix: <scope the query / add the guard / re-check server-side>

REQUESTS (N):
  - <mass-assignment risk, missing deny-by-default, ambiguous public marking>
```

## Rules

- READ-ONLY by default — this command audits and reports; it does not edit code unless explicitly asked to fix.
- Every matrix row carries its three citations or it is a finding.
- A client-side guard / hidden control NEVER counts as an authorization check.
- An id-loading endpoint with no citable ownership predicate is a BLOCKER (IDOR), not a REQUEST.
- Deny-by-default is the expected posture: an endpoint with neither a guard nor an explicit `@Public()` is UNGATED = BLOCKER.
- Do not trust route names — `/admin/*` with no guard is ungated; `/public/*` that returns tenant data is mis-marked.
