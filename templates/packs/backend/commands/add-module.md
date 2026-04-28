---
description: Scaffold a new backend module end-to-end following the project's declared architecture. Generates entity + ports + use-cases + repo + controller + DTOs + migration + DI wiring + tests + docs.
---

# /add-module

Create a complete module. Called directly OR from inside `/add-feature`.

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## When to use / NOT to use

- USE: a new bounded-context entity warranting its own module (CRUD + business rules).
- USE: when called by `/add-feature` for a new entity in the feature.
- NOT: adding an endpoint to an existing module → `/add-endpoint`.
- NOT: shared utility / helper code → goes in this project's shared library directory (whatever the codebase calls it — `libs/shared/`, `pkg/shared/`, `internal/`, `common/`, etc., as detected at extraction), not a module.
- NOT: throwaway / experimental code — modules carry conventions and tests.

## Phase 1 — Understand (the ask)

Ask (one consolidated question if unclear):
- Module name (singular or plural — match repo convention).
- One-line purpose.
- Has HTTP? Has webhooks? Has queue consumer? Has background job?
- Multi-tenant scope? (default: yes if project is multi-tenant.)
- Soft-delete? (default: match project convention.)
- Fields (name + type + constraints).

State the success criteria: complete module (core + application + infrastructure + adapters + DI + migration + tests + i18n + docs) wired into the app, mirroring an existing sibling.

## Phase 2 — Organize (design dispatch)

Parallel dispatches:

- `api-architect` — module file layout, API surface, DTO shape, use-case list, DI tokens.
- `schema-architect` — entity schema, indexes, FKs, migration plan.
- `telemetry-architect` — logs + metrics + traces + alerts for this module.
- `test-engineer` — test plan (what to unit/integration/e2e test).

**Pause. User confirms design.**

Decide order of generation: core → application → infrastructure → adapters → DI → migration → tests → locales → docs.

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

MODULE-SPECIFIC:
- `.claude/rules/`.
- `ai/architecture.md` + `ai/patterns/project-structure.md`.
- A SIBLING MODULE end-to-end. Mirror its every file, name, export style.
- `ai/patterns/api-contract.md`, `error-handling.md`, `multi-tenancy.md` (if applicable), `indexing-strategy.md`, `migrations.md`.
- `.claude/references/<framework>.md` for idiomatic shape.

EXISTING CODE:
- The chosen sibling module — every file, every name, every import.

## Phase 4 — Generate (scaffold + tests)

Generate in this order (dependencies build up):

### core/ layer (pure, no framework)

```
core/
├── entities/<name>.ts              # domain entity — plain TS class or record
├── errors/<name>-not-found.error.ts
├── errors/<name>-already-exists.error.ts  (if uniqueness relevant)
├── ports/<name>.repository.ts       # interface
└── ports/<name>-external.port.ts    (if external dep needed)
```

### application/ layer

```
application/use-cases/
├── create-<name>.use-case.ts
├── get-<name>.use-case.ts
├── list-<name>s.use-case.ts
├── update-<name>.use-case.ts
└── delete-<name>.use-case.ts
```

Each use-case: single intent. Constructor-injected dependencies via interfaces.

### infrastructure/ layer

```
infrastructure/persistence/
├── <name>.orm-entity.ts           # ORM entity
├── <name>.mapper.ts                # ORM <-> domain mapper
└── <name>.repository.impl.ts       # implements the port
```

ORM entity includes:
- `tenant_id` + `@Index` (if multi-tenant).
- Base entity fields (id, createdAt, updatedAt, deletedAt if soft-delete).
- Audit fields (createdBy, updatedBy) per project convention.
- Indexes per schema-architect's design.

Repository.impl.ts extends project's base repo (tenant-scoped, soft-delete-aware).

### adapters/ layer

```
adapters/http/
├── <name>.controller.ts
└── dtos/
    ├── create-<name>.dto.ts         # class-validator / zod / pydantic
    ├── update-<name>.dto.ts
    ├── list-<name>s-query.dto.ts    # pagination + filters
    └── <name>.response.dto.ts
```

Controller: thin. Parses → calls use-case → maps response via mapper.

Endpoints (standard CRUD — adjust per project conventions):
- `POST /<plural>` → create, returns 201
- `GET /<plural>` → list, with pagination
- `GET /<plural>/:id` → get one, 404 if not found
- `PATCH /<plural>/:id` → update, 200
- `DELETE /<plural>/:id` → soft-delete, 204

All require auth by default. Multi-tenant filter applied automatically via base repo + `TenantContext`.

### DI wiring

```
tokens.ts:
  export const <name>Tokens = {
    SERVICE: Symbol.for('<Name>.Service'),
    REPOSITORY: Symbol.for('<Name>.Repository'),
    MAPPER: Symbol.for('<Name>.Mapper'),
  };

<name>.module.ts:
  providers: [
    { provide: tokens.REPOSITORY, useClass: <Name>RepositoryImpl },
    { provide: tokens.SERVICE, useClass: <Name>Service },
    { provide: tokens.MAPPER, useClass: <Name>Mapper },
  ],
  exports: [tokens.SERVICE, tokens.MAPPER],
```

No magic strings. Tokens are symbols in `tokens.ts`.

### Migration

Invoke `/add-migration`:
- Create table per schema-architect's design.
- All indexes + FKs + constraints.
- Reversible.

### Tests

```
__tests__/
├── create-<name>.use-case.spec.ts            # unit
├── get-<name>.use-case.spec.ts
├── list-<name>s.use-case.spec.ts
├── update-<name>.use-case.spec.ts
├── delete-<name>.use-case.spec.ts
├── <name>.repository.impl.spec.ts            # integration (real DB)
└── <name>.controller.e2e-spec.ts              # e2e (HTTP)
```

Required scenarios:
- Happy path per use-case.
- Error path per typed error.
- Cross-tenant leak test on the repo.
- Auth test on each endpoint (unauth = 401).
- Validation test (invalid body = 400).

### Locales (if project has i18n messages)

```
<module>/locales/
├── en.json
└── ar.json
```

Keys for success + error messages referenced from the controller's response.

### Domain-specific additions (signal-based)

If the module handles a domain signal, auto-include:

| Signal | Addition |
|---|---|
| Multi-tenant | TenantScopedRepository + cross-tenant leak test |
| AI / LLM | Prompt builder + cost tracking on outbound |
| Webhook | Signature verifier middleware + idempotency table |
| Payment | Idempotency key required + provider key passed through |
| Cross-service | Retry + timeout + circuit breaker per external call |
| Audit-required (GDPR) | AuditLog subscriber on entity lifecycle |

### Observability

Apply telemetry-architect's design:
- Structured logs at key state changes (create/update/delete + errors).
- Metrics: request counter + latency histogram per endpoint, business metric if relevant.
- Trace spans wrapping use-case + external calls.
- Alert rules if SLO-relevant.

## Phase 5 — Update (persist changes to the knowledge base)

Wire into the app:
- Import module in `app.module.ts` (or equivalent root).
- Add route prefix if applicable.
- If module introduces a new permission set — wire into RBAC config.

Knowledge base updates:
- Prepend Recent Changes entry to `ai/status.md`.
- Add row to `ai/modules.md` for the new module.
- If a new pattern emerged → add `ai/patterns/<new>.md`.
- If an architectural decision was made → ADR.
- Append one-line summary to `ai/dynamic/changelog.md`.

## Phase 6 — Validate (verify + review)

Run in order:
- `pnpm lint` scoped to generated files.
- `pnpm test` scoped to `__tests__/` of this module.
- `pnpm dev` + `endpoint-test` skill for each endpoint (200 / 400 / 401 verified).
- `schema-diff` skill — entity matches DB after migration.
- Self-audit: do the generated files cross-reference correctly? Any contradictions with `ai/conventions.md`?

If any check fails: HALT, report the failure, do not paper over.

## Phase 7 — Improve (feed the learning loop)

- Run `/learn-from-task` to capture: module created, sibling mirrored, signals applied, follow-ups.
- If the chosen sibling mirror revealed inconsistencies (the sibling itself drifted from `ai/patterns/project-structure.md`): append to `ai/dynamic/drift-log.md`.
- If a brand-new domain signal emerged (project's first webhook module): queue ADR consideration via `ai/dynamic/decisions-pending.md`.
- If user redirected scaffolding (different folder layout, different DI style): append correction to `ai/dynamic/feedback-learned.md`.

## Output

```
✅ Module scaffolded: <name>

Phase 1 (Understand): name=<X>, purpose=<Y>, multi-tenant=<bool>, signals: <list>.
Phase 2 (Organize): 4 architects dispatched in parallel; design confirmed.
Phase 3 (Retrieved): 7 universals + sibling module + 5 patterns.
Phase 4 (Generated): <N> files across core/application/infrastructure/adapters + tests + locales.
Phase 5 (Updated): ai/modules.md (+1), ai/status.md (Recent Changes), app.module.ts wired.
Phase 6 (Validated): lint, tests, endpoint-test (5 endpoints), schema-diff clean.
Phase 7 (Improved): /learn-from-task queued.

Files created: <N>
  core/           (entity, errors, ports)
  application/    (<N> use-cases)
  infrastructure/ (orm-entity, mapper, repo)
  adapters/http/  (controller + <N> DTOs)
  tokens.ts, <name>.module.ts
  __tests__/      (<N> test files)
  migration <NNNN>-create-<name>-table.sql

Agents dispatched: api-architect, schema-architect, telemetry-architect, test-engineer
Skills run: endpoint-test, schema-diff

Endpoints (all require auth):
  POST   /<plural>
  GET    /<plural>
  GET    /<plural>/:id
  PATCH  /<plural>/:id
  DELETE /<plural>/:id

Test coverage:
  Unit: <N> scenarios (happy + errors + boundaries)
  Integration: cross-tenant leak test included
  E2E: auth + validation + golden path

Telemetry:
  Metrics: <list>
  Alerts: <list>

Docs updated:
  ai/status.md (Recent Changes entry)
  ai/modules.md (+1 row)

Status: COMPLETE

Next:
  - /review-changes
  - /security-audit (if sensitive domain)
  - Commit + PR
```

## Hard rules

- Mirror an existing module EXACTLY. No invented layout.
- DI tokens are Symbols, not strings.
- Every DTO validated.
- Tenant filter on every query (if multi-tenant).
- Migration reversible.
- Tests shipped with code (never separate PR).
- Cross-tenant leak test mandatory for multi-tenant.
- Auth on every endpoint unless explicitly public.
- `ai/modules.md` + `ai/status.md` updated before merge.

## Related

### Sibling commands in backend pack
- `/add-endpoint` — sibling command in backend pack
- `/add-feature` — sibling command in backend pack
- `/analyze-module` — sibling command in backend pack
- `/endpoint-test` — sibling command in backend pack
- `/fix-bug` — sibling command in backend pack
- `/log-tail` — sibling command in backend pack
- `/trace-flow` — sibling command in backend pack

### Patterns
- `ai/patterns/api-contract.md`
- `ai/patterns/api-versioning.md`
- `ai/patterns/caching-strategy.md`
- `ai/patterns/error-handling.md`
- `ai/patterns/parallel-io.md`

### Rules
- `.claude/rules/backend-principles.md`
- `.claude/rules/concurrency-discipline.md`
