---
description: Add a new endpoint to an EXISTING module. Full chain — DTO + use-case + controller + mapper + tests + telemetry + docs. Smaller than /add-module, deeper than "edit controller".
---

# /add-endpoint

Use when extending a module. Smaller than `/add-module` (no new entity), deeper than hand-editing the controller (full chain with tests + telemetry).

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## When to use / NOT to use

- USE: a new HTTP endpoint on an existing module.
- USE: a new event handler / queue consumer in an existing module.
- USE: when the new behavior fits the module's domain (no new entity).
- NOT: a brand-new module → `/add-module`.
- NOT: a hand-edit on an existing endpoint → just edit, then `/review-changes`.
- NOT: cross-module orchestration → `/add-feature`.

## Phase 1 — Understand (the ask)

Ask (one consolidated question):
- Which module?
- HTTP method + path (or event name for queue consumer).
- Purpose (one line — what the endpoint does, what it returns).
- Request shape (fields + types + validation).
- Response shape.
- Auth requirement (public / authenticated / admin / custom role).
- Any side effects (events emitted, external calls, notifications)?

State the success criteria: endpoint live + 3+ e2e tests + telemetry + docs prepended + zero placeholders.

## Phase 2 — Organize (design with api-architect)

Dispatch `api-architect` scoped to this endpoint. Output:
- DTO(s) in + out — fields, types, validation.
- Use-case name + single intent.
- Dependencies use-case needs (repos, clients).
- Controller route wiring (guards, status code).
- Error paths + HTTP status mapping.
- Telemetry emitted.

Plan dispatch: schema-reviewer (if DB touched), telemetry-architect for endpoint metrics, test-engineer for scenarios.

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

ENDPOINT-SPECIFIC:
- Target module — every file. Especially existing controller + one sibling use-case.
- `.claude/references/<framework>.md`.
- `ai/patterns/api-contract.md`, `error-handling.md`.
- `ai/patterns/idempotency.md` (if POST/PATCH + retry-sensitive).
- Domain pattern per signal (multi-tenancy, webhook, AI, payment).

EXISTING CODE:
- Mirror an existing endpoint in this module EXACTLY. No new pattern.
- 1-2 sibling controllers in the same module — confirm shape.

## Phase 4 — Generate (files + tests)

Follow the module's existing shape.

### DTOs

```
adapters/http/dtos/
├── <verb>-<resource>.dto.ts           # input (e.g., create-order.dto.ts)
└── <resource>-response.dto.ts         # output if not shared (often reuse existing)
```

Input DTO:
- Every field has validator (class-validator / zod / pydantic).
- Optional ≠ nullable (be explicit).
- Nested with `@ValidateNested()` + `@Type()`.
- No `any`.

Output DTO:
- Plain typed class/interface.
- NEVER the ORM entity.

### Use-case

```
application/use-cases/<verb>-<resource>.use-case.ts
```

Single intent. Shape:

```ts
@Injectable()
export class <Verb><Resource>UseCase {
  constructor(
    @Inject(Tokens.REPOSITORY) private readonly repo: <Resource>Repository,
    @Inject(Tokens.EVENT_BUS) private readonly events: EventBus,
    // ...
  ) {}

  async execute(input: <Verb><Resource>Input): Promise<<Resource>> {
    // 1. Validate business rules (pre-conditions)
    // 2. Fetch / modify / save domain object
    // 3. Emit events / side effects
    // 4. Return the result
  }
}
```

No HTTP types (`Request`, `Reply`). No ORM types in return.

### Controller method

```ts
@<Method>('<path>')
@HttpCode(<explicit>)
@UseGuards(<auth guards>)
@Permissions('<scope>')  // if permission-based
async <verb><Resource>(
  @Body() dto: <Verb><Resource>Dto,
  // @Param('id') id: string,  (if applicable)
): Promise<ApiResponse<<Resource>ResponseDto>> {
  const result = await this.useCase.execute({ /* map dto → use-case input */ });
  // If the project has a response-envelope helper from extraction, use it; otherwise return the DTO directly.
  return <project's response wrapper if any>(this.mapper.toDto(result), <i18n message key if any>);
}
```

Status codes:
- 201 on create (POST that creates).
- 200 on update / read (default).
- 204 on delete (no body).
- 202 if processed async.

### Repository method (if new query pattern)

If the endpoint needs a new query:
- Declare on the port interface first: `core/ports/<resource>.repository.ts`.
- Implement in the infra repo: `infrastructure/persistence/<resource>.repository.impl.ts`.
- Tenant filter + soft-delete filter applied via base.

### Events (if emitted)

```
core/events/<resource>-<verb>ed.event.ts     # e.g., order-placed.event.ts
```

Event class with minimal data (IDs, not full entities). Handlers registered in `<module>.module.ts`.

### Migration (if schema changed)

Via `/add-migration`. Reversible. Safe on populated tables (expand-contract if needed).

### Tests

Mandatory scenarios:

#### Unit (use-case)
```ts
describe('<Verb><Resource>UseCase', () => {
  it('succeeds with valid input', async () => { /* ... */ });
  it('throws <DomainError> when <condition>', async () => { /* ... */ });
  it('emits <event> on success', async () => { /* ... */ });
});
```

#### Integration (repo — if new method)
```ts
describe('<Resource>RepositoryImpl', () => {
  it('persists correctly', async () => { /* ... */ });
  it('does not return tenant B data to tenant A', async () => { /* ... */ });  // if multi-tenant
});
```

#### E2E (controller)
```ts
describe('<METHOD> <path>', () => {
  it('201 on valid request (auth)', async () => { /* ... */ });
  it('400 on invalid body', async () => { /* ... */ });
  it('401 unauthenticated', async () => { /* ... */ });
  it('403 insufficient permission', async () => { /* ... */ });  // if permission-gated
  it('409 on conflict', async () => { /* ... */ });               // if uniqueness rules
  it('404 when resource not found', async () => { /* ... */ });    // for GET/PATCH/DELETE
});
```

Minimum 3 e2e tests for a mutating endpoint: happy + invalid body + unauth.

### Telemetry

Dispatch `telemetry-architect` for this endpoint. At minimum:
- Request counter: `http_requests_total{endpoint="<METHOD> <path>", status}`.
- Latency histogram: `http_request_duration_seconds{endpoint=...}`.
- Log entries: entry + success / failure with correlation id.
- Trace span wrapping use-case (auto if OpenTelemetry instrumented).
- Business metric if applicable (order placed, payment succeeded).
- Alert if SLO-bearing (error rate, latency p95).

Dispatch `/add-telemetry` if gaps.

### Domain-specific requirements (signal-based)

| Signal | Extra requirement |
|---|---|
| Multi-tenant | Every query filters by tenant_id. Cross-tenant e2e test. |
| POST/PATCH retry-sensitive | `Idempotency-Key` header accepted, stored, replayed. |
| AI / LLM | max_tokens set. Tokens + cost logged. |
| Webhook (inbound) | HMAC verified BEFORE processing. Idempotency by provider event id. |
| Payment | Idempotency key. Provider call uses the key. Typed PaymentError hierarchy. |
| File upload | Type + size + magic-bytes validated. Safe storage path. |
| Public endpoint | Rate limit (per IP) + body size limit. |

## Phase 5 — Update (persist changes to the knowledge base)

- Prepend `ai/status.md` Recent Changes entry.
- If introducing a new public API path → update API docs / Swagger + commit `openapi.json` baseline update.
- If an ADR's worth of decision emerged → new ADR.
- Append one-line summary to `ai/dynamic/changelog.md`.
- For UI changes triggered by the new endpoint: regenerate i18n keys in `locales/`.

## Phase 6 — Validate (verify + review)

- `pnpm lint` on the new files.
- `pnpm test` on the new tests.
- Run `coverage-gap` skill — all new branches covered?
- `endpoint-test` skill against dev server — 200 + 400 + 401 scenarios run through.
- `api-snapshot` skill — is this a breaking change? If yes and no ADR → fail.

### Review (parallel)

Dispatch:
- `api-reviewer` — architecture + contract + data access + observability.
- `schema-reviewer` — if DB touched.
- `test-reviewer` — coverage + determinism + mocks.
- `security-auditor` — if auth / crypto / secrets / sensitive data.
- `tenant-isolation-reviewer` — if multi-tenant.
- `prompt-reviewer` — if AI code touched.

If any check fails: HALT, report the failure, do not paper over.

## Phase 7 — Improve (feed the learning loop)

- Run `/learn-from-task` to capture: endpoint shape, sibling mirrored, telemetry added, follow-ups.
- If a new use-case shape emerged (3+ similar ones in this module): queue to `ai/dynamic/learned-patterns.md`.
- If user redirected the design (e.g., wanted async-202 instead of sync-200): append to `ai/dynamic/feedback-learned.md`.
- If a new domain signal surfaced (first webhook in the project): queue ADR consideration.

## Output

```
✅ Endpoint added: <METHOD> <path>

Phase 1 (Understand): module=<X>, purpose=<Y>, signals: <list>.
Phase 2 (Organize): api-architect designed; <N> tests planned.
Phase 3 (Retrieved): 7 universals + module files + 1 sibling controller + signal patterns.
Phase 4 (Generated): DTO, use-case, controller method, tests (<N>), telemetry.
Phase 5 (Updated): ai/status.md, ai/dynamic/changelog.md (+ openapi.json if public).
Phase 6 (Validated): lint, tests, endpoint-test (200/400/401), api-snapshot, reviewers.
Phase 7 (Improved): /learn-from-task queued.

Files:
  - adapters/http/dtos/<N>.dto.ts
  - adapters/http/<existing-controller>.ts (edited)
  - application/use-cases/<verb>-<resource>.use-case.ts
  - infrastructure/persistence/... (if new query method)
  - __tests__/<N>.spec.ts

Tests: <N> scenarios (unit + integration + e2e)

Telemetry added:
  - Metric: <list>
  - Log: <list>
  - Trace: <list>
  - Alert: <list or "none — not SLO-bearing">

Review verdict: APPROVE / REQUEST_CHANGES / BLOCK

Domain checks:
  - Multi-tenant: cross-tenant leak test ✓
  - Idempotency: key accepted + replay verified ✓ (if retry-sensitive)
  - Security audit: no blockers

Docs updated: ai/status.md

Breaking change?: NO (additive) / YES → ADR NNNN + openapi snapshot updated.

Status: COMPLETE

Next:
  - /review-changes
  - Commit + PR
```

## Hard rules

- Mirror existing endpoints in this module EXACTLY. No new pattern.
- DTO validated. Every field. No `any`.
- Auth guards unless explicitly public.
- Tests shipped with code.
- Multi-tenant → cross-tenant test mandatory.
- Breaking API change → ADR + openapi snapshot updated.
- Telemetry included, not bolted on.
