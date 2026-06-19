---
name: migration-backend
description: Backend-specific extensions to migration-discipline — audit axes, primitive set, anti-patterns, fingerprints. Stack examples are illustrative; substitute equivalents from your project's `_extracted-idioms.md`.
kind: rule
pack: backend
severity: must
applies-to: backend-track, every-code-writing-task-in-backend
extends: migration/rules/migration-discipline.md
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. Inline syntax in this file uses one stack as illustration; substitute your stack's primitives from `_extracted-idioms.md`.


# Backend extensions to migration discipline

The universal `migration-discipline.md` rule defines V1→V2 port discipline in stack-agnostic terms. This file adds the backend-specific surface the universal rule references.

This rule applies to V1→V2 ports in any backend codebase (Node / Python / PHP / Ruby / Java / Go / Elixir / .NET).

## Backend audit axes (when feature is an HTTP endpoint / RPC handler / event consumer)

The 6 generic comparison axes from the universal rule (Inputs / Outputs / Error contract / Auth + permissions / Side effects / Performance) apply. Backend ports add these specific axes for any feature whose entry is a route handler / controller method / RPC / event subscriber:

- **Endpoints / route handlers** — every HTTP route the feature exposes: method (GET/POST/PUT/DELETE/PATCH), path, named middlewares, controller method, response status codes.
- **Request/Response DTO shape** — every field in the request and response: name, type, validators, defaults, required vs optional, nested structures.
- **Auth + permissions** — every guard / middleware applied to the route: auth check, role check, tenant check, rate-limit.
- **Inputs / validation** — every validator decorator or schema field: type assertions, length bounds, enum constraints, custom validators.
- **Side effects** — DB queries, external HTTP calls, queue publishes, cache reads/writes, log emissions, metric emissions, file I/O.
- **Service-layer methods invoked** — which service / repository methods the handler calls; the handler-to-service contract.
- **Error contract** — every exception type the handler throws, the HTTP status it maps to, error response shape.
- **Tenant isolation** (multi-tenant projects) — every query has a tenant filter; every cache key has a tenant prefix; every event payload carries tenant context.
- **Transaction boundaries** — start/commit/rollback per request; nested transactions; saga compensation.

## Stack-aware primitive set (backend)

The validator's `extract_inventory_primitives` extracts these primitive classes from backend files. Auto-promote thresholds (count differential > 30%) trigger standard-tier audit requirements.

| Primitive | What it counts (across NestJS / Express / Fastify / Laravel / Django / FastAPI / Flask / Rails / Sinatra / Spring / Go / Phoenix / ASP.NET) | Axis (where the audit must enumerate the gap) |
|---|---|---|
| `route_handler` | `@Get(` / `@Post(` / `@Put(` / `@Delete(` / `@Patch(` decorators, `app.get(` / `router.get(`, `Route::get(`, `path('...')`, `@app.get(`, `@app.route('...')`, `(get|post|put|delete|patch) "/path"`, `@(Get|Post|Put|Delete)Mapping(`, `\.(GET|POST|PUT|DELETE)(`, `[Http(Get|Post|Put|Delete)]` | Endpoints / route handlers |
| `dto_class` | `class \w+(Dto|Request|Response|Schema)`, `class \w+ extends BaseModel`, `class \w+Serializer(`, `type \w+(Request|Response) struct`, `class \w+(VO|Bean|Form)`, `defmodule \w+\.\w+Schema` | Request/Response DTO shape |
| `auth_guard` | `@UseGuards(`, `@AuthGuard(`, `passport.authenticate(`, `middleware('auth')`, `@login_required`, `@permission_required`, `Depends(get_current_user)`, `before_action :authenticate`, `@PreAuthorize(`, `@Secured(`, `plug :authenticate`, `[Authorize]` | Auth + permissions |
| `validator` | `@IsString(` / `@IsEmail(` / class-validator decorators, `Joi.object(`, `yup.string(`, `z.string(`, `Field(` / `validator(` (Pydantic), `\w+Field(` (DRF), `@NotNull(` / `@Email(` (Bean Validation), `validates :name`, `'name' => 'required'`, `validate:"required"` (Go struct tag), `[Required]` / `[EmailAddress]` (.NET) | Inputs / validation |
| `service_method` | Inside `*service*` / `*Service*` / `*_service*` files: public methods (signature pattern per language) | Service-layer methods invoked |
| `exception_throw` | `throw new \w+(Error|Exception)`, `raise \w+(Error|Exception)`, `errors.New(`, `fmt.Errorf(`, `abort(`, language-specific exception spawn | Error contract |
| `db_query` | ORM method calls: `.findOne(`, `.find(`, `.create(`, `.update(`, `.delete(`, `::where(`, `::find(`, `objects.filter(`, `Repo.get(`, raw SQL keywords (`SELECT`, `INSERT INTO`, `UPDATE ... SET`, `DELETE FROM`) | Side effects (DB) |
| `event_emit` | `eventEmitter.emit(`, `.publish(`, `dispatch(`, `applicationEventPublisher.publishEvent(`, `Phoenix.PubSub.broadcast(`, signal `.send(`, `ActiveSupport::Notifications.publish(` | Side effects (events / queue) |

The `extract_inventory_primitives` function is framework-comprehensive within `backend-*` — it patterns 13+ frameworks across Node / Python / PHP / Ruby / Java / Go / Elixir / .NET. Adding a new framework requires only a new pattern alternation in the function.

## Backend Transposition Trap fingerprints

Concrete backend fingerprints the validator's `check_v2_structure` flags when `PROJECT_KIND in backend-*`:

- **Fat controller** when V2 architecture mandates service-layer + repository: route handlers with > N lines of business logic that V2 expects to live in a service.
- **Raw SQL string concat** when V2 mandates parameterized queries / ORM only.
- **`SELECT *` queries** consumed by < 5 fields downstream (column-projection over-fetch).
- **N+1 query patterns** — 1 query + per-result follow-ups in a loop where a JOIN or batch query is the V2 idiom.
- **Sync external HTTP in request hot path** when V2 architecture has a queue/worker primitive for async deferral.
- **Missing tenant filter** in multi-tenant queries — query lacks the `WHERE tenant_id = ?` predicate the V2 architecture mandates.
- **Direct DB access from controller** when V2 mandates repository-pattern indirection.
- **Manual `Authorization: Bearer` header construction** in inter-service calls — bypasses the centralised auth client.
- **Catch-and-swallow** in service methods (`catch { /* ignore */ }`) — fails silently instead of routing through the project's error handler.

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
- Validator script: `scripts/validate-migration-artifacts.sh § extract_inventory_primitives` (stack-conditional via `PROJECT_KIND`)
