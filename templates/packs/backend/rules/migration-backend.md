---
name: migration-backend
description: Backend-specific extensions to migration-discipline — the V1→V2 transposition-trap fingerprints, the port audit axes, and the primitive classes the parity validator counts. Stack examples are illustrative; substitute equivalents from your project's `_extracted-idioms.md`.
kind: rule
pack: backend
severity: must (when a migration layout is detected)
applies-to: backend-track, v1-to-v2-ports
extends: migration/rules/migration-discipline.md
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. Inline syntax in this file uses one stack as illustration; substitute your stack's primitives from `_extracted-idioms.md`.

# Backend extensions to migration discipline

**This file owns ONE axis: the V1→V2 port.** Its two siblings own the others and it never restates them — `backend-principles.md` is what you MUST do in code you are writing fresh, `concurrency-discipline.md` is the async / fan-out axis in any code at all. What is left over, and what nothing else in this pack covers, is the failure class that exists only while you are TRANSPOSING an implementation somebody already shipped: code that was correct inside V1's architecture and is wrong inside V2's, carried across intact *because it worked*. Nobody writes a fat controller on purpose in a codebase that mandates a service layer; you get one by pasting V1's controller into V2. That is the entire subject of this file, and it is why § Backend Transposition Trap fingerprints leads it.

Unlike `backend-principles.md`, this rule is not always on. It ships only when a migration layout is detected (`_topics.md § migration-backend`), so it costs a project that is not porting anything exactly nothing.

The universal `migration-discipline.md` defines port discipline in stack-agnostic terms; this file adds the backend surface that rule references, for any backend codebase (Node / Python / PHP / Ruby / Java / Go / Elixir / .NET).

## Backend Transposition Trap fingerprints

Concrete backend fingerprints the validator's `check_v2_structure` flags when `PROJECT_KIND in backend-*`:

- **Fat controller** when V2 architecture mandates service-layer + repository: a route handler that holds business logic V2 places in a service — branching on domain state, computing money/totals/eligibility, or orchestrating more than one repository call. Judge by what the logic *is*, not by a line count: there is no project-independent threshold, and a literal `N` in a MUST-severity rule is unenforceable.
- **Raw SQL string concat** when V2 mandates parameterized queries / ORM only.
- **`SELECT *` queries** consumed by < 5 fields downstream (column-projection over-fetch).
- **N+1 query patterns** — 1 query + per-result follow-ups in a loop where a JOIN or batch query is the V2 idiom.
- **Sync external HTTP in request hot path** when V2 architecture has a queue/worker primitive for async deferral.
- **Missing tenant filter** in multi-tenant queries — query lacks the `WHERE tenant_id = ?` predicate the V2 architecture mandates.
- **Direct DB access from controller** when V2 mandates repository-pattern indirection.
- **Manual `Authorization: Bearer` header construction** in inter-service calls — bypasses the centralised auth client.
- **Catch-and-swallow** in service methods (`catch { /* ignore */ }`) — fails silently instead of routing through the project's error handler.

## DI markers

`migration/_failure-surface.md` routes here for the concrete syntax of its "framework marker in the wrong layer" fingerprint — a service-registration decorator, annotation, attribute, provider entry or container-registration call appearing inside the domain or pure-application layer. This file deliberately does not name that syntax, because it is a per-project fact and a guessed one is worse than none: read it, do not recall it.

- The registration convention this codebase actually uses → `.claude/_extracted-idioms.md § DI / module wiring`.
- Which directories are the domain / pure-application layers → `.claude/_extracted-codebase.md § Layering`.

The fingerprint fires when the first appears inside the second. If extraction produced neither, **that is the finding** — report the missing anchor and stop, rather than substituting the marker from whichever framework you saw most recently.

## Backend audit axes (when the feature's entry is a route handler / RPC / event consumer)

The 6 generic comparison axes from the universal rule (Inputs / Outputs / Error contract / Auth + permissions / Side effects / Performance) apply. The backend axes that extend them are stated **once**, as the axis column of the table below — seven of the nine are exactly what the parity validator already counts, and a second prose list of the same seven would drift against it.

`scripts/validate-migration-artifacts.sh § extract_inventory_primitives` (defined at `:1211`, called on both sides of the port at `:1799-1800`) counts eight primitive classes in a V1 file and its V2 counterpart. Drift fires when V1 > 0 and V2 / V1 < 0.7 — V2 missing more than 30% of a class. On a PARITY verdict that is a hard fail (*verdict contradicted by primitive inventory*); otherwise it falls through to DRIFT enumeration. No tier changes by itself — a trivial-tier PARITY row drifting by 5 or fewer only warns, and raising the tier is a human call.

The regex alternations that recognise each class across 13+ frameworks (Node / Python / PHP / Ruby / Java / Go / Elixir / .NET) live in that function and only there. A prose copy here would be a second source of truth with nothing comparing the two, and no agent follows a regex alternation anyway — the validator does. What an agent follows is the mapping: count these classes on both sides of the port, and enumerate every gap on the axis named beside it.

| Primitive class | Audit axis | What the enumeration must list, per site |
|---|---|---|
| `route_handler` | Endpoints / route handlers | method, path, named middlewares, controller method, response status codes |
| `dto_class` | Request/Response DTO shape | field name, type, defaults, required vs optional, nested structure |
| `auth_guard` | Auth + permissions | auth check, role check, tenant check, rate limit |
| `validator` | Inputs / validation | type assertion, length bound, enum constraint, custom validator |
| `service_method` | Service-layer methods invoked | the handler-to-service contract: which service / repository methods are called |
| `exception_throw` | Error contract | exception type, the status it maps to, error response shape |
| `db_query` | Side effects (DB) | query, and whether it reads or writes |
| `event_emit` | Side effects (events / queue) | queue publish, cache write, log/metric emission, file I/O |
| — none — | **Tenant isolation** `[self-policed]` | every query's tenant filter, every cache key's tenant prefix, every event payload's tenant context |
| — none — | **Transaction boundaries** `[self-policed]` | begin/commit/rollback per request, nested transactions, saga compensation |

The last two rows are the point of the table. No primitive class counts them, so **the drift ratio is structurally blind to a port that dropped every tenant filter or every transaction boundary** — a green validator run says nothing about either. Those two axes are enumerated by hand or they are not enumerated; a port audit that reports only the counted eight has audited eight tenths of the surface and should say so rather than reading as complete.

Widening framework coverage is a change to that function's pattern alternation, never an edit here.

## Phase 3 (Retrieve) — backend specifics

The universal rule's Phase 3 mandates "read V2's gold standards before writing." For backend:

- **Endpoint** → read the gold-standard endpoint pattern in V2 (typically the highest-quality controller in `_extracted-codebase.md § Gold standards`).
- **Service** → read at least 2 V2 services in the same module + the canonical base service (or stack-equivalent, e.g., `BaseRepository`, `BaseService`).
- **DTO** → read 1-2 V2 DTOs that use the same shared validators.
- **Migration / schema change** → read the V2 migration toolchain doc + 1-2 prior migrations.

Mirror these files' shape: same layering pattern, same shared-class substitutions (V2's BaseService / BaseRepository / BaseDto), same error-handling pattern.

## Cross-references

- Universal discipline: `migration/rules/migration-discipline.md`
- Backend principles: `backend/rules/backend-principles.md`
- Backend concurrency: `backend/rules/concurrency-discipline.md`
- Validator script: `scripts/validate-migration-artifacts.sh § extract_inventory_primitives` (`:1211`, stack-conditional via `PROJECT_KIND`) — the single source of truth for the primitive regexes
