---
description: Add a new endpoint to an EXISTING module. Full chain — DTO + use-case + controller + mapper + tests + telemetry + docs. Smaller than /add-module, deeper than "edit controller".
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. Inline syntax in this file uses NestJS + TypeScript for illustration; substitute your stack's primitives from `_extracted-idioms.md`.


# /add-endpoint

Use when extending a module. Smaller than `/add-module` (no new entity), deeper than hand-editing the controller (full chain with tests + telemetry).

## Nested-invocation mode

**Nested invocation (called from /add-feature):** if invoked by `/add-feature` with a passed payload (Spec-ID/spec path + the parent's Phase-1 requirements + the relevant Phase-2 architect design slice + resolved signals) → SKIP Phase 1's derive-and-ask block entirely (the parent already resolved it; re-deriving is the contract breach its § Dispatch contract names), SKIP the Phase-2 architect re-dispatch, and SKIP the prior-art gate (the parent already cleared the capability); consume the payload and proceed to Generate. Still run the sibling-shape halt on the files this command produces (its own grain). When called DIRECTLY (no payload) → run the full flow as written.

## Prior-art gate (all tiers, runs before tier selection)

Sibling search finds an endpoint to *copy*; this gate asks first: **does the behavior already exist** under another route/handler name? A second copy of an existing capability is the costliest waste mode and sibling-mirror does not catch it.

1. Search by **behavior, not name** — route paths, handler/use-case names, domain verbs that would already cover the ask.
2. **Near-duplicate found → HALT.** Surface the existing endpoint (path + what it does) and ask: extend it, replace it, or ship a deliberate parallel (rare — one-line PR rationale).
3. Nothing matches → proceed to tier selection.

## Closure verbs (complexity → ceremony)

Default to the lightest tier that fits. Heavy ceremony is opt-in, not default.

| Tier | Triggers | Artifacts | Phases |
|---|---|---|---|
| **Trivial** (default) | 1 endpoint mirroring a sibling endpoint exactly (same module, read or simple write). No new pattern element. | Code + tests (happy + invalid body + unauth). **No plan, no ADR, no Phase 5 docs.** | Understand (light) → Generate → Validate (sibling-shape halt) |
| **Standard** | New DTO shape / new query method / new event handler, but reuses existing primitives. | Code + tests + 1-paragraph plan + sibling-shape note in PR. **`n-plus-one-scan` on any new list / query endpoint.** **No ADR unless pattern is genuinely new.** | Understand → Retrieve (siblings) → Generate → Validate |
| **Heavy** | New auth surface, write-path mutation, cross-module orchestration, schema change, payment / multi-tenant surface, breaking API change. | ADR + plan + reviewer dispatch + parity tests for affected siblings. Full 7-phase ceremony below. | All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve) |

**Most endpoints are trivial.** If the sibling-shape halt (Phase 6) flags a new primitive or cross-module touch, it promotes the row to standard or heavy — the agent does NOT pre-emptively pick heavy "to be safe."

## New-dependency gate (all tiers)

Inherited from `/add-feature` (§ New-dependency gate). Condensed: a package no sibling already uses never lands silently — confirm it's actually new (check the lockfile), run a dependency review (maintenance / license / bloat / stdlib-alternative; dispatch `security-auditor` or inline the checklist), and record the decision (one PR line; ADR for auth / crypto / payment / data-handling deps). HALT on an unreviewed new dependency.

## Phases applied

Heavy tier runs all 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve). Trivial / standard tiers run the subset their closure-verb tier requires (see the table above) — skipping phases outside your tier's ceremony is sanctioned; skipping phases inside it is not.

## When to use / NOT to use

- USE: a new HTTP endpoint on an existing module.
- USE: a new event handler / queue consumer in an existing module.
- USE: when the new behavior fits the module's domain (no new entity).
- NOT: a brand-new module → `/add-module`.
- NOT: a hand-edit on an existing endpoint → just edit, then `/review-changes`.
- NOT: cross-module orchestration → `/add-feature`.

## Phase 1 — Understand (the ask)

### Intent gate

If description suggests a different intent, halt with redirect: "fix / broken / wrong" → `/fix-bug`. "optimize / slow / N+1" → `/optimize-query`. "audit / review" → `/security-audit` (if security-flavored) or `/perf-audit`. "enhance" → not applicable to backend endpoints (proceed; new endpoint IS the enhancement). Proceed only for adding a new endpoint / route / event handler.

### Standard inputs — derive from siblings, ask only for what they cannot answer

**Siblings are the truth, and this command reads them before it opens its mouth.** Phase 3 already
mandates *"Mirror an existing endpoint in this module EXACTLY"* and *"1-2 sibling controllers in the
same module — confirm shape."* Asking the user for request shape, response shape or auth in Phase 1
and then overwriting all three from siblings two phases later is a questionnaire pretending to be a
tool: it spends the user's attention on answers the run will discard.

**Resolve from the module first.** Locate ≥1 sibling handler on the target module and read off:

| Input | Derived from | Print as |
|---|---|---|
| Request shape (fields, types, validators) | the sibling's input DTO / schema — same validator library, same optional-vs-nullable convention, same nesting style | `request: mirrors <path:line>` |
| Response shape | the sibling's response DTO / serializer and the envelope it returns through | `response: mirrors <path:line>` |
| Auth requirement | the guard / decorator / middleware stack on the sibling route, plus the module-level guard | `auth: mirrors <path:line>` |
| Side effects | the events / outbox writes / external clients the sibling use-case already emits | `side effects: none beyond <path:line>` |

**Print the derived block before Phase 2 and let the user correct it.** A four-line inference the
user can override in one sentence costs less of their attention than a four-part question, and it is
the difference between a tool and a form.

**The agent ONLY asks the user when:**
- **No sibling exists** on the module (first endpoint on a fresh module — nothing to mirror).
- **New auth surface** — the route needs a role, scope or guard no sibling on this module uses. A
  new authorization boundary is never inferred; guessing it wrong is a security defect, not a nit.
- **A side effect no sibling emits** — a first outbound call, a first published event, a first
  payment or notification. New blast radius is a decision, not a shape.

Everything else — validator idiom, DTO file naming, status code on create, envelope shape, pagination
convention, error-code prefix — is silent sibling-mirror. Only `<module>`, `<METHOD> <path>` and a
one-line purpose are genuinely the caller's to supply, and the first two are usually in the argument.

**Nested invocation already obeys this** (`/add-feature` § Dispatch contract: *"leaves don't
re-derive"*). This block is the same contract for the direct-invocation path, which previously had
none.

State the success criteria: endpoint live + 3+ e2e tests + telemetry + docs prepended + zero placeholders. This is the *functional* floor. The *done* condition is the Phase-6 Production-readiness gate — all seven production-floor items MET-with-evidence or n-a-with-reason, else the run reports INCOMPLETE with the unmet items named.

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

ALWAYS (the universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

**MUST read** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) before generating code.

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

### Controller / handler method

The example below is shown in NestJS-style decorators, but the SHAPE applies to any backend: route → guard → input DTO → delegate to service/use-case → map result → return wrapped response. In a non-NestJS stack, replace decorators with the framework's idiom (Express middleware, FastAPI dependencies, Spring annotations, etc.). Helpers like `createApiResponse(...)` and `this.successMessages.<key>` are placeholders for **whatever response-envelope + i18n message helpers THIS project actually has** (from `.claude/_extracted-codebase.md`). If the project has no such helper, return the DTO directly.

```ts
@<Method>('<path>')
@HttpCode(<explicit>)
@UseGuards(<auth guards>)
@Permissions('<scope>')  // if permission-based
async <verb><Resource>(
  @Body() dto: <Verb><Resource>Dto,
  // @Param('id') id: string,  (if applicable)
): Promise<<ResponseShape — project-specific>> {
  const result = await this.useCase.execute({ /* map dto → use-case input */ });
  // If this codebase has a response-envelope helper (detected at extraction):
  //   return <projectResponseHelper>(this.mapper.toDto(result), <i18n message key>);
  // Otherwise:
  //   return this.mapper.toDto(result);
  return <project's response wrapper or plain DTO>;
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
  it('422 on invalid body (project's declared validation status)', async () => { /* ... */ });
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

Dispatch `/add-telemetry` if gaps *(observability pack, when co-installed)*. **A redirect must land somewhere** — when that pack is absent, emit the missing span / counter / log inline against the project's existing telemetry primitives (`references/<framework>.md`) and record it in the report; never route a gap into a command the project does not have.

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
| Expensive / unauthenticated | Rate limit (token-bucket or sliding-window) per tenant / user / IP; over-limit returns `429 Too Many Requests` (RFC 6585) + `Retry-After` (RFC 9110 §10.2.3, seconds or HTTP-date); emit the quota fields `RateLimit-Policy` + `RateLimit` (IETF `draft-ietf-httpapi-ratelimit-headers` — still a draft; the `RateLimit-Limit`/`-Remaining`/`-Reset` triple is draft-05 legacy, so emit both while clients migrate, and never invent `X-RateLimit-*` on a new endpoint). Declare FAIL-OPEN vs FAIL-CLOSED when the limiter store is down. e2e asserts the `(N+1)`-th call in the window is 429 + carries `Retry-After`. Ref `ai-patterns/rate-limiting.md`. (ENF-1) |
| Async (202) | Response returns `202 Accepted` + `Location: /jobs/:id` AND a `GET /jobs/:id` status endpoint exists (job-status state machine: queued → running → succeeded / failed, result URL + TTL on success). Consumer is idempotent + visibility-timeout + DLQ + bounded retry. e2e: `POST → 202 → poll status → terminal-state`. Ref `ai-patterns/async-job-offload.md`. (ENF-3 / PERF-3) |
| Streaming (SSE / chunked / NDJSON / LLM token stream) | Dispatch `@websocket-engineer` for backpressure / heartbeat / resume; set BOTH idle and total timeout; cancel the upstream work on client disconnect; mid-stream terminal error uses a sentinel frame (status already 200 — cannot change it). LLM streams cap `max_tokens` + log tokens / cost. Chunked + trailers = RFC 9112. e2e: client-disconnect aborts the upstream. Ref `ai-patterns/response-streaming.md`. (ENF-4) |
| GET list / collection endpoint | Applies a default + hard-max page size (an unbounded list is rejected/clamped); stable total sort with a unique tiebreaker; cursor/keyset for growing tables (offset only for small quiescent ones); pagination meta in the project envelope; avoid `COUNT(*)` per page (limit+1 / `hasMore`). e2e asserts an over-cap `limit` is clamped and that pages don't drop/repeat rows under an insert. Ref `ai-patterns/pagination.md`. (API-8) |
| Bulk / batch | Per-item status array; declare the contract — all-or-nothing (`200` whole batch / `4xx` reject whole batch) vs best-effort (`207 Multi-Status`, per-item outcomes). Size cap on the array. Idempotency-Key is batch-scoped, not per-item. (API-3) |
| Conditional / contended write | Resource backed by a `version` / `updated_at` column emits a strong `ETag` and requires `If-Match` on the write (`412 Precondition Failed` on stale, `428 Precondition Required` when the header is absent); the GET honors `If-None-Match` → `304 Not Modified`. ETag / If-Match / If-None-Match / 304 / 412 / 428 = RFC 9110 (obsoletes RFC 7232). Ref `ai-patterns/conditional-requests.md`. (API-1) |
| Write endpoint binding to a persisted entity | Explicit field-allowlist bind — never bind the whole request body onto the entity. Over-post (mass-assignment) e2e asserts a privileged field (e.g. `isAdmin`, `tenantId`, `balance`) sent in the body is ignored. Owned by the **forms / security** domain — pointer, not duplicated policy. (SEC-01) |
| Endpoint fetches a user-supplied URL | SSRF egress allowlist: block private / link-local / loopback / cloud-metadata ranges, https-only, validate the *resolved* IP (re-resolve, defeat DNS-rebind), no redirects to denied hosts. e2e rejects a metadata-IP (`169.254.169.254`) and a loopback target. Owned by **security-auditor (OWASP A10 SSRF)** — pointer, not duplicated policy. (SEC-02) |
| Privileged / role-change / data-export / payment-change | Write an immutable audit record (actor / target / before-after / source IP / timestamp) to a separate append-only store, retention per compliance regime. This is NOT RED metrics and NOT app logs. Spec owned by **security-principles** + **observability telemetry-architect** — pointer, not duplicated policy. (OBS-3) |

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
- `endpoint-test` skill against dev server — success, invalid-body (at the project's declared validation-failure status — `422` for a well-formed body that fails semantics, `400` only for an unparseable one) and 401 scenarios run through.
- `api-snapshot` skill — is this a breaking change? If yes and no ADR → fail. If the snapshot flags a **removal / breaking change** to an existing surface, the superseded route MUST emit `Deprecation` (RFC 9745) + `Sunset` (RFC 8594, HTTP-date) headers for the announced overlap window before it disappears — failing to announce the retirement is itself a fail. (ENF-2)

### Review (parallel)

Dispatch:
- `api-reviewer` — architecture + contract + data access + observability.
- `schema-reviewer` — if DB touched.
- `test-reviewer` — coverage + determinism + mocks.
- `security-auditor` — if auth / crypto / secrets / sensitive data.
- `tenant-isolation-reviewer` — if multi-tenant.
- `prompt-reviewer` — if AI code touched.
- `payment-reviewer` — if payment code touched.
- `@websocket-engineer` — if the endpoint streams (SSE / chunked / NDJSON / LLM token stream): verify backpressure, heartbeat, resume, idle + total timeout, and disconnect-aborts-upstream. (ENF-4)

If a named agent is not installed in this project, perform that review inline against the corresponding pack/domain checklist — never silently skip the axis.

If any check fails: HALT, report the failure, do not paper over.

### Production-readiness gate (the done-condition — replaces "tests are green")

**"Returns 200" is the floor, not the bar.** A green happy-path test, a clean lint, and a dispatched reviewer prove the endpoint is *functional*. They do NOT prove it is *production-grade*. This gate is the comparative step: the build is not `done` until each item on the production floor below is **MET with cited evidence**, **n-a with a stated reason**, or **UNMET / SKIPPED** — and if any floor item is UNMET or SKIPPED, the run reports **INCOMPLETE with that item named**, never a silent `COMPLETE`.

The evidence source is the `api-reviewer` **Production-readiness verdict** table (dispatched above) — this gate READS that block; it does not re-judge. A floor row the reviewer marked `UNMET` / `SKIPPED (unverified)` is an unmet item here. No reviewer installed → run the reviewer's floor detectors inline; the evidence rule is unchanged (a row with no citable evidence is UNMET, never a faked MET).

Fill this ledger (one row per floor item) before writing the Output block:

| # | Production floor | MET requires (evidence — a claim is not evidence) | Wired to |
|---|---|---|---|
| 1 | **Input validated at the edge** | every input DTO field has a validator AND the invalid-body e2e test passes (named), asserting the project's declared validation-failure status — `422` for a well-formed body that fails semantics, `400` only for an unparseable one (`ai-patterns/error-handling.md` § Status mapping) | api-reviewer `edge-validation`; `endpoint-test` skill (invalid-body case) |
| 2 | **Standard error envelope** | error paths return the project envelope / Problem Details (RFC 9457) at a cited `<path:line>`; no stack trace / PII leaked | api-reviewer `error-envelope` + error-contract |
| 3 | **Correct transaction boundary** | a multi-write use-case is wrapped in ONE transaction at the service layer (cite the tx site); no external call held inside the tx — OR `n-a` (single write), reason stated | api-reviewer `txn-boundary` (TXN). `[self-policed]` — no grep proves two writes are one unit |
| 4 | **Idempotency on unsafe methods where the convention requires** | `Idempotency-Key` accepted + stored + a replay e2e test proves the second call returns the first result — OR `n-a`, reason stated (naturally idempotent PUT / not retry-sensitive) | api-reviewer `idempotency`; signal table row |
| 5 | **No N+1 / unbounded query** | `n-plus-one-scan` clean on any new list/query path AND (for a list endpoint) a default + hard-max page size is enforced (over-cap `limit` clamp asserted by e2e) | `n-plus-one-scan` skill; api-reviewer `no-N+1`/pagination (API-8, PERF-5) |
| 6 | **Authz enforced, not just authn** | a `403` **denial** e2e test for an authenticated-but-unauthorized principal (wrong role / non-owner) passes — a `401` alone does NOT satisfy this — OR `n-a` (truly public endpoint), reason stated | api-reviewer `authz-not-authn` (AUTHZ) |
| 7 | **Emits log + metric + trace** | the RED-triad metric (rate + errors + duration histogram), a correlation-id log line, and a use-case span are each matched to an **actually-emitted** signal in the diff — not asserted from the telemetry plan | api-reviewer `log+metric+trace` (OBS-2); Phase-4 Telemetry |

**Coverage regeneration (evidence #1, #5, #6 are runtime — not readable from source alone).** Where the evidence is a test that must be *run* (invalid-body, 403 denial, page-cap clamp), the gate requires the test **executed green in this run** (from `pnpm test` / `endpoint-test`), not merely authored. If the harness is absent (no dev server, `n-plus-one-scan` not installed), mark that row `SKIPPED — unverified: <exact command a reviewer must run>` and the verdict is INCOMPLETE, not PRODUCTION-READY.

**Verdict:**
- **PRODUCTION-READY** — every floor row is MET (with evidence) or n-a (with reason). Only then may the Output say the endpoint is shippable.
- **INCOMPLETE** — one or more floor rows UNMET or SKIPPED. The Output lists each unmet row + why + the exact next action. This is a legitimate, honest terminal state — it is NOT a failure to paper over. Do not stamp COMPLETE to look finished.

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
Phase 6 (Validated): lint, tests, endpoint-test (200/422/401), api-snapshot, reviewers.
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

Production-readiness ledger (from the Phase-6 gate — every floor row MUST resolve):
  1. edge-validation     MET   — every DTO field validated; invalid-body e2e green at the declared status
  2. error-envelope      MET   — Problem Details at <path:line>; no stack/PII leak
  3. txn-boundary        n-a   — single write (or: MET — wrapped at <path:line>)
  4. idempotency         MET   — key stored + replay e2e green   (or n-a — not retry-sensitive)
  5. no-N+1 / bounded    MET   — n-plus-one-scan clean; page-cap clamp e2e green
  6. authz-not-authn     MET   — 403 denial e2e (wrong role) green   (NOT just 401)
  7. log+metric+trace    MET   — RED triad + correlation-id log + span emitted in diff

Domain checks (signal-gated):
  - Multi-tenant: cross-tenant leak test ✓
  - Security audit: no blockers

Docs updated: ai/status.md

Breaking change?: NO (additive) / YES → ADR NNNN + openapi snapshot updated.

Verdict: PRODUCTION-READY   (all 7 floor rows MET or n-a, evidence cited)

Next:
  - /review-changes
  - Commit + PR
```

When any floor row is UNMET or SKIPPED, emit the honest terminal state instead — never the block above:

```
⚠ Endpoint added but NOT production-ready: <METHOD> <path>

Verdict: INCOMPLETE

Unmet floor items:
  6. authz-not-authn     UNMET   — only a 401 test exists; no 403 denial test for a
                                   non-owner. Next: add e2e asserting owner-B gets 403 on
                                   PATCH of owner-A's resource, then re-run the gate.
  7. log+metric+trace    SKIPPED — unverified: no metrics scrape in this env.
                                   Next: run `endpoint-test` against dev + confirm the
                                   duration histogram series appears.

Met: 1,2,3,4,5.   Shippable only after 6 & 7 close.
```

Never stamp COMPLETE/PRODUCTION-READY while a floor row is open — INCOMPLETE with the named items is the correct, honest report.

## Hard rules

- Mirror existing endpoints in this module EXACTLY. No new pattern.
  - Reviewer must verify the new endpoint's shape matches ≥2 sibling endpoints in the same module — no new pattern introduced silently.
- DTO validated. Every field. No `any`.
- Auth guards unless explicitly public.
- Tests shipped with code.
- Multi-tenant → cross-tenant test mandatory.
- Breaking API change → ADR + openapi snapshot updated.
- Telemetry included, not bolted on.
- **Authz, not just authn** — an owned/role-scoped endpoint ships with a `403` denial test for the wrong principal; a `401` alone does not certify the endpoint.
- **Done means production-ready, not functional.** The Production-readiness gate (Phase 6) is the closure condition: every floor item MET-with-evidence or n-a, else report INCOMPLETE with the unmet items — never stamp COMPLETE on a green happy path alone.

## Related

### Sibling commands — where the boundary falls
- `/add-module` — **owns the entity.** New aggregate, new tables, new layer set → there. This command assumes the module, its repository and its guard stack already exist.
- `/add-feature` — **owns anything crossing two modules.** When it calls this command it passes its resolved Phase-1/Phase-2 payload down; a leaf that re-derives is a contract breach (§ Nested-invocation mode).
- `/endpoint-test` — verifies on the wire what this command claimed. The production-readiness gate below is a static check; that command is the empirical one.
- `/fix-bug` — the route already exists and behaves wrongly. Adding a second route beside a broken one is the waste mode the prior-art gate exists to catch.

### Patterns
- `ai/patterns/api-contract.md` — the envelope and the evolution rules the new route must land inside.
- `ai/patterns/error-handling.md` — the error shape and status mapping the handler emits.
- `ai/patterns/request-validation.md` — the boundary schema + writable-field allow-list for the input DTO.
- Signal-gated: `multi-tenancy.md` (tenant-scoped resource), `pagination.md` (list route), `conditional-requests.md` (contended write), `async-job-offload.md` (work over the hot-path budget), `rate-limiting.md` (public or expensive route).

The rest of the pack's patterns are not read on this axis and are deliberately not listed.

### Rules
- `.claude/rules/backend-principles.md`
- `.claude/rules/concurrency-discipline.md`
