---
description: Scaffold a new backend module end-to-end following the project's declared architecture. Generates entity + ports + use-cases + repo + controller + DTOs + migration + DI wiring + tests + docs.
---

# /add-module

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/add-module <name> --plan` plans the full module (entity + ports + use-cases + repo + controller + DTOs + migration + DI + tests) against the closest sibling module and exits before any edit. Execute it later with `/execute-plan <file>` (or hand it to any tool).

Create a complete module. Called directly OR from inside `/add-feature`.

## The Premise (read this first, internalize, do not deviate)

**Existing modules are the truth.** The project already has modules — same layer split (core / application / infrastructure / adapters), same DI primitive, same error envelope, same naming convention, same test layout, same migration shape. That existing module IS the project's intentional truth. The new module does not get to invent a different layout. Future maintainers can't predict where things live, fixes can't be applied uniformly, and the codebase fragments by one more weight every time someone improvises.

**The agent's job is exactly this:**
1. Find ≥1 sibling module in the same pack (closest neighbor by domain shape: same multi-tenancy posture, same HTTP / queue / job mix).
2. Read its end-to-end shape — file paths, layer boundaries, DI tokens style, error envelope, validation library, ORM mapper pattern, controller thinness, test scaffolding.
3. Mirror that shape for the new module. Innovating without precedent is the failure mode.

**The agent does NOT:**
- Ask the user about layout / file naming / DI style. **Mirror the sibling silently.**
- Reach for a layout from training data when a sibling exists. **Sibling wins.**
- Draft an ADR to legitimize a deviation. **Mirror the sibling, no ADR.**

**The agent ONLY asks the user when:**
- **No sibling module exists** — this is the project's first module. Ask once, get the shape blessed, then mirror it forever after.
- **The new module needs a primitive the project has never used** (first async queue, first webhook, first event-sourced aggregate).
- **Cross-module coupling** — a new dependency between modules that didn't talk before; that's an ADR.

That's it. Three escalation triggers. Everything else is silent sibling-mirror with the closure verbs below.

## Nested-invocation mode

**Nested invocation (called from /add-feature):** if invoked by `/add-feature` with a passed payload (Spec-ID/spec path + the parent's Phase-1 requirements + the relevant Phase-2 architect design slice + resolved signals) → SKIP the Phase-1 Ask block, SKIP the Phase-2 architect re-dispatch, and SKIP the prior-art gate (the parent already cleared the capability); consume the payload and proceed to Generate. Still run the sibling-shape halt on the files this command produces (its own grain). When called DIRECTLY (no payload) → run the full flow as written.

## Prior-art gate (all tiers, runs before tier selection)

Sibling search finds a module to *copy*; this gate asks first: **does the capability already exist** under another module name? A second module covering the same bounded context is the costliest waste mode and sibling-mirror does not catch it.

1. Search by **behavior, not name** — existing modules, entities, table/column names, domain verbs that would already cover the ask.
2. **Near-duplicate found → HALT.** Surface the existing module (path + what it does) and ask: extend it, replace it, or ship a deliberate parallel (rare — one-line PR rationale).
3. Nothing matches → proceed to tier selection.

## New-dependency gate (all tiers)

A package no sibling module already uses never lands silently — confirm it's actually new (check the lockfile), run a dependency review (maintenance / license / bloat / stdlib-alternative; dispatch `security-auditor` or inline the checklist), and record the decision (one PR line; ADR for auth / crypto / payment / data-handling deps). HALT on an unreviewed new dependency.

## Closure verbs (complexity → ceremony)

Default to the lightest tier that fits. Heavy ceremony is opt-in, not default.

| Tier | Triggers | Artifacts | Phases |
|---|---|---|---|
| **Trivial** (default) | New CRUD module mirroring 1 sibling 1:1. No new primitive. No cross-module coupling. | Code + tests + migration + `ai/modules.md` row. **No plan, no ADR, no Phase 5 docs beyond modules.md / status.md.** | Understand (light) → Generate (mirror sibling) → Validate (sibling-shape halt) |
| **Standard** | New module reuses primitives but has 1 novel axis (new domain signal: webhook, AI, payment, queue). | Code + tests + migration + 1-paragraph plan + sibling-shape note in PR. | Understand → Retrieve (sibling + 1 pattern) → Generate → Validate |
| **Heavy** | First module of its kind in repo, OR cross-module coupling, OR new layer/primitive, OR write-path with multi-tenant blast radius. | Full ADR + 7-phase ceremony below + reviewer dispatch. | All 7 |

**Default is trivial.** Most "new module" requests mirror an existing CRUD. If the sibling-shape halt (Phase 6) flags drift or a new primitive, it promotes the row to standard or heavy — the agent does NOT pre-emptively pick heavy "to be safe."

## Sibling-shape halt (mechanical gate, all tiers)

**Before declaring success, the auditor compares the new module's files against the chosen sibling module's files, axis by axis.** This is the same `regressed` mechanism from `parity-auditor.md` — borrowed for greenfield modules.

Halt if the new module:
- **Has files at paths that don't match the sibling layout** (e.g., `src/<module>/handlers/` when siblings live at `src/<module>/adapters/http/`).
- **Imports utilities the sibling doesn't import** (sign of pattern drift — fetched from training data instead of mirrored).
- **Uses an error type / DI primitive / validation library / ORM mapper style siblings don't use** (raw `try/catch` when siblings use a `Result` envelope; magic-string DI tokens when siblings use `Symbol.for(...)`; `zod` when siblings use `class-validator`).
- **Names exports / classes / files differently** (PascalCase vs camelCase drift; `*Service` vs `*Manager` suffix drift; singular vs plural folder drift).
- **Skips a layer the sibling has** (no mapper, no port interface, controller talks to repo directly).

Halt verdict per file: `aligned` (matches sibling) | `drifted` (one or more axes diverge) | `no-sibling-found` (escalate to user).

Any `drifted` → HALT before merge. Either re-shape to match the sibling (default closure) or — if the deviation is intentional and load-bearing — write an ADR justifying it and promote to heavy tier. Drift without ADR is forbidden.

For trivial-tier modules, this halt is the only gate beyond lint+tests+migration. No reviewers, no telemetry sign-off — just sibling parity.

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve) — **heavy tier only**. Trivial / standard rows skip directly to Phase 4 (Generate), apply sibling-mirror, run the sibling-shape halt, and ship.

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

ALWAYS (the universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

MODULE-SPECIFIC:
- `.claude/rules/`.
- `ai/architecture.md` + `ai/patterns/project-structure.md`.
- A SIBLING MODULE end-to-end. Mirror its every file, name, export style.
- `ai/patterns/api-contract.md`, `error-handling.md`, `multi-tenancy.md` (if applicable), `indexing-strategy.md`, `migrations.md`.
- `.claude/references/<framework>.md` for idiomatic shape.

EXISTING CODE:
- The chosen sibling module — every file, every name, every import.

## Phase 4 — Generate (scaffold + tests)

**The scaffold contract is OWNED by the `module-scaffold` skill — this command dispatches it, it does not re-implement it.** Mirror how `/refactor` dispatches `refactoring-sweep` (single source of the verb set): there, the command owns the gates and the skill owns the transformation; here, `/add-module` owns the gates above (prior-art / new-dependency / sibling-shape / nested-invocation mode) and `module-scaffold` owns the file tree, the generated-file invariants, and the per-layer generation order.

### Dispatch

Dispatch [`templates/packs/backend/skills/module-scaffold.md`](../skills/module-scaffold.md) with the resolved inputs (module name, purpose, signals, multi-tenant / soft-delete / i18n flags, the chosen sibling path, and — for heavy tier — the architects' design slices from Phase 2). The skill generates:

- `core/` (entity, errors, ports), `application/use-cases/` (CRUD), `infrastructure/persistence/` (orm-entity + mapper + repository.impl), `adapters/http/` (controller + DTOs).
- DI wiring (`tokens.ts` Symbols + `<name>.module.ts`), reversible migration, the test tree (unit + integration + e2e + wiring smoke spec).
- `ai/modules.md` row + `ai/status.md` Recent Changes entry + app-root module import.
- All under the skill's generated-file invariants (every DTO validated, tenant filter on every query if multi-tenant, soft-delete base class, Symbol DI tokens, reversible `up()`/`down()`, real assertions — no `// TODO`).

`/add-module` does NOT duplicate that file tree or those invariants here — see the skill for the authoritative contract. The CRUD endpoints (`POST /<plural>` 201, `GET` list+paginate, `GET /:id` 404, `PATCH /:id`, `DELETE /:id` soft-delete) and locale keys (`en.json` / `ar.json` for success + error messages) are part of that contract.

### What `/add-module` layers ON TOP of the scaffold (its own value beyond the skill)

`module-scaffold` produces CRUD plumbing. `/add-module` adds the domain-signal + observability layers below before the sibling-shape halt runs.

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
- Heavy-tier rows additionally dispatch signal-aware reviewers: `security-auditor` (auth/secrets), `tenant-isolation-reviewer` (multi-tenant), `prompt-reviewer` (AI), `payment-reviewer` (payment). If a named agent is not installed in this project, perform that review inline against the corresponding pack/domain checklist — never silently skip the axis. HALT on any BLOCKER.

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

### Skills
- `module-scaffold` — the apply-engine this command dispatches in Phase 4 (owns the file tree + generated-file invariants; single source of the scaffold contract).

### Patterns
- `ai/patterns/api-contract.md`
- `ai/patterns/api-versioning.md`
- `ai/patterns/caching-strategy.md`
- `ai/patterns/error-handling.md`
- `ai/patterns/parallel-io.md`

### Rules
- `.claude/rules/backend-principles.md`
- `.claude/rules/concurrency-discipline.md`
