---
description: One command UI/UX + API + Schema + Platform polish, stack-conditional. Deep multi-agent execution. Sibling to /migrate / /optimize / /align — same simple-surface pattern, applied to consistency + finish quality. Routes detectors + closure verbs by PROJECT_KIND. Frontend-* → visual UI/UX polish (hierarchy, spacing rhythm, design tokens, missing UI states, CTA consistency, motion, focus, type scale, icon vocabulary). Backend-* → API consistency (envelope shape, error contract, pagination, naming, idempotency, log/metric/trace uniformity, OpenAPI completeness). Data-* → schema consistency (column naming, types, indexes, audit fields, migration patterns). Mobile-* → frontend polish + platform conventions (iOS HIG / Material). NO phases visible, NO terminology, NO mid-run questions. Output is brief: surfaces polished, commits, diff stats, test status, stack-appropriate quality deltas. Distinct from /enhance-ui (pack-level single-area iteration loop) and /ui-sweep (specialist with HTML report) — /polish is the multi-day whole-project simple-surface entry, working on any stack.
kind: command
pack: orchestration
---

# /polish [<scope>]

## What this does

**Single command. Make the project's surface look + feel finished.** Deep multi-agent diagnosis + creative cleanup. Whole project or scoped. Multi-day workflow. **Stack-conditional** — dispatches detectors + closure verbs based on `PROJECT_KIND`.

What "polish" means depends on the stack:

| Stack | Focus | Example findings |
|---|---|---|
| `frontend-*` | Visual + UX consistency | Missing empty/loading/error states; CTA placement drift; hardcoded colors → tokens; type-scale drift; motion inconsistency; focus state missing |
| `backend-*` | API consistency + observability uniformity | Response envelope drift; error-contract drift; pagination drift; idempotency-key missing; log-field naming drift; metric/trace naming drift; OpenAPI gaps |
| `data-*` | Schema + migration consistency | Column naming drift (snake/camel); type-choice drift (VARCHAR vs TEXT for same concept); index-naming drift; audit-field gaps; migration pattern drift; soft-delete coverage |
| `mobile-*` | Frontend polish + platform conventions | All frontend findings + iOS HIG conformance + Material spec conformance + per-platform surface adaptations |

The agent:
1. **Reads the project's design / API / schema / platform conventions** — `_extracted-idioms.md`, `ai/conventions.md`, `ai/architecture.md`, `_extracted-codebase.md § Gold standards`. These are the oracle for what "polished" means in this codebase.
2. **Audits every relevant surface** — pages/modals/dashboards (frontend); endpoints/handlers/responses (backend); tables/migrations/queries (data); screens + platform manifests (mobile).
3. **Closes drift mechanically** — hardcoded values → tokens / shared types / canonical names. Same closure-verb grammar across stacks; only the targets change.
4. **Adds creative polish in parallel** — empty/loading/error states (frontend); idempotency keys + standard error envelopes (backend); audit columns + soft-delete (data); platform-conforming surfaces (mobile).
5. **Iterates variants** for frontend surfaces flagged "visually weak" (3 style variants generated; user picks; skill applies — only when audit explicitly opts in). Backend / data / mobile do NOT iterate; they unify-or-not.

## Stack-conditional detector dispatch

### Frontend (`frontend-*`)

Skills: `a11y-quick-check`, `design-iterate`, `design-token-audit`, `motion-audit` (ui-ux pack).

Detectors:
- visual-hierarchy / spacing-rhythm / hardcoded-design-values / missing-empty-state / missing-loading-skeleton / missing-error-state / cta-placement-drift / density / motion-inconsistency / icon-mismatch / type-scale-drift / color-drift / affordance-clarity / focus-state-missing / responsive-drift / cross-page-consistency

Closure verbs:
- `apply-token`, `extract-token` (propose new token when ≥3 duplicates), `add-empty-state`, `add-loading-skeleton`, `add-error-state`, `unify-cta-placement`, `consolidate-icon`, `apply-type-scale`, `simplify-density`, `clarify-affordance`, `add-focus-animation`, `extract-pattern` (≥5 instance duplicates).

### Backend (`backend-*`)

Skill: `api-consistency-audit` (backend pack).

Detectors:
- response-envelope-drift (different endpoints return different shapes for `{data, meta, errors}` or whatever the project's envelope is).
- error-contract-drift (4xx/5xx don't follow uniform shape).
- naming-convention-drift (camelCase vs snake_case mixed across endpoints).
- pagination-drift (cursor vs offset / page+limit mixed).
- versioning-drift (some endpoints v1, some v2 with no documented deprecation).
- auth-header-drift (`Authorization` vs `X-API-Key` vs custom mixed).
- idempotency-key-missing (POST/PUT/DELETE without idempotency support where the project's convention requires it).
- rate-limit-header-drift (some endpoints expose `X-RateLimit-*`, others don't).
- log-field-drift (structured logs use different field names for the same concept — `userId` vs `user_id` vs `uid`).
- metric-name-drift (counter / histogram naming inconsistent — `orders.created` vs `OrderCreated` vs `order_created_total`).
- trace-span-drift (span names / attributes inconsistent across endpoints).
- timeout-policy-drift (different default timeouts across services with no documented reason).
- retry-policy-drift (retry counts / backoff inconsistent).
- openapi-coverage-gap (endpoints not documented in the spec).
- example-coverage-gap (endpoints documented but no example payloads).

Closure verbs:
- `unify-envelope`, `unify-error-contract`, `unify-naming`, `unify-pagination`, `unify-versioning`, `unify-auth-header`, `add-idempotency-key`, `unify-rate-limit-headers`, `unify-log-fields`, `unify-metric-names`, `unify-trace-spans`, `unify-timeout-policy`, `unify-retry-policy`, `add-openapi-doc`, `add-endpoint-example`.

### Data (`data-*` or backend with significant schema/migrations)

Skill: `schema-consistency-audit` (database pack).

Detectors:
- column-naming-drift (snake_case vs camelCase in column names within the same DB).
- type-drift (some tables use `VARCHAR(255)`, others `TEXT`, for the same conceptual field).
- index-naming-drift (`idx_*` vs `ix_*` vs `<table>_<col>_idx`).
- foreign-key-naming-drift.
- migration-pattern-drift (some migrations have rollback, others don't; some are reversible, others irreversible without documentation).
- timestamp-column-drift (`created_at` vs `createdAt` vs `created` vs `inserted_at`).
- soft-delete-drift (some tables have `deleted_at`, others don't where the project's convention requires it).
- audit-field-drift (`updated_by` / `created_by` inconsistently applied).
- timezone-drift (`TIMESTAMP` vs `TIMESTAMPTZ` mixed).
- charset-drift (`utf8` vs `utf8mb4`).
- collation-drift.
- nullable-drift (same conceptual field nullable in some tables, NOT NULL in others).

Closure verbs:
- `unify-column-naming`, `unify-type-choice`, `unify-index-naming`, `unify-fk-naming`, `unify-migration-pattern`, `unify-timestamp-cols`, `add-soft-delete`, `add-audit-fields`, `unify-timezone`, `unify-charset`, `unify-collation`, `unify-nullable`.

### Mobile (`mobile-*`)

Skill: `platform-conventions-audit` (mobile pack), reused frontend skills (a11y / design-iterate / design-token-audit / motion-audit).

Detectors: ALL frontend detectors PLUS:
- ios-hig-drift (touch targets < 44pt, navigation patterns non-conformant, system fonts not used where appropriate).
- material-spec-drift (Android Material 3 component usage drift, elevation/shadow drift, ripple states missing).
- platform-icon-drift (iOS uses Cupertino icons; Android uses Material icons; mixed usage = drift).
- platform-typography-drift (San Francisco vs Roboto not honoured per platform).
- per-platform-surface-drift (iOS-specific affordances missing; Android-specific affordances missing).
- haptic-feedback-coverage (missing haptics where convention dictates).
- safe-area-handling (notches / home indicators not respected).

Closure verbs: ALL frontend closure verbs PLUS:
- `apply-platform-spec`, `unify-platform-icon`, `apply-platform-typography`, `add-haptic-feedback`, `respect-safe-area`.

## When to use

- "Polish the whole project." → `/polish`
- "Polish the API surface." → `/polish` (on a backend project)
- "Polish the schema." → `/polish` (on a data project)
- "Polish the dashboard." → `/polish the dashboard` (frontend)
- "Tighten the orders endpoints." → `/polish the orders module` (backend)
- After a feature merge that landed without polish.
- Pre-launch consistency sweep.

## When NOT to use

- Single-area iteration with style-variant picking → `/enhance-ui <area>` (frontend pack-level).
- Specialist whole-project visual audit with HTML report → `/ui-sweep` (frontend only, deeper).
- Read-only audit, no edits → `/design-review` (frontend) / `api-consistency-audit` skill (backend) / `/db-audit` (data).
- Pure convention drift across all classes (not just polish) → `/align`.
- Code quality / perf / refactoring → `/optimize`.
- New features → `/add-feature`.
- V1→V2 port → `/migrate`.

## Args

- `<scope>` (optional) — natural-language description OR explicit path. If omitted: whole project.

Examples:
```
/polish                                  # whole project (any stack)
/polish the orders module                # one module (any stack)
/polish the dashboard                    # one page (frontend)
/polish the /orders endpoints            # backend scope
/polish the analytics schema             # data scope
/polish <modules-root>/auth/             # explicit path
/polish "the customer-facing pages"      # multi-page semantic scope
/polish the login page --direction="cleaner padding, stronger CTA"  # frontend with iteration hint
```

## What happens internally (silent)

1. **Detect stack** — read `PROJECT_KIND` from `_extracted-codebase.md § Gold standards`. If `unknown`, halt with "set PROJECT_KIND first via `/setup-project --refine`".
2. **Dispatch the right skill set** per the stack-conditional table above.
3. **Audit** — runs the stack's detectors across the scope. Captures baselines (visual screenshots for frontend; OpenAPI snapshot for backend; schema dump for data; per-platform surface tree for mobile).
4. **Resolve scope** — semantic resolution.
5. **Plan internally** — group by surface (pages → modules → shared layouts for frontend; endpoints → controllers → middlewares for backend; tables → migrations for data). Foundation patterns first (token / envelope / column-name additions before consumer fixes). NO phase output to user.
6. **Multi-agent parallel fix** — dispatch one agent per surface cluster. Closure verbs from the stack's closed vocabulary.
7. **Variant iteration** (frontend only) for surfaces flagged "visually weak" — generates 3 style variants; user picks; skill applies. Skipped on `--no-iterate` or non-frontend stacks.
8. **Verify continuously** — lint + typecheck + scoped tests + a11y check (frontend) / contract tests (backend) / schema-validate (data) / per-platform smoke (mobile). Plus stack-specific deltas (visual-regression for frontend; OpenAPI-diff for backend; schema-diff for data).
9. **Self-resolve common questions** — design system / API conventions / schema conventions / platform spec are the truth.
10. **Halt only on genuine blockers**:
    - `PROJECT_KIND` is `unknown` (halts the whole run).
    - Token / envelope / column-name primitive missing where fix needs one — surfaces "/setup-project --refine to add primitive first".
    - Visual-regression collateral on a NON-target surface (frontend; halts that fix).
    - OpenAPI breaking change (backend; halts; user must approve via ADR).
    - Schema migration that's irreversible (data; halts; user must approve via ADR).
    - User-decision required for variant selection (frontend; only when audit explicitly opted into iteration).

## Progress tracking (multi-day workflow)

Single source of truth: **`ai/polish/progress.md`**.

### How it works

- **First run** → builds surface inventory (stack-appropriate: pages/modals/components for frontend; endpoints/handlers for backend; tables/migrations for data; screens/manifests for mobile) + writes progress file (all `pending`). Runs first surface.
- **Subsequent runs** → reads progress file, picks next `pending` surface (or use `<scope>` arg). Already-`done` surfaces skipped.
- **`/polish --status`** → read-only progress report; no work done.

### Progress file shape (frontend example)

```markdown
# Polish progress

Started: 2026-05-03
Stack: frontend-vue
Codebase: <project-root>/src/

## Summary
- Total surfaces:  47 (22 pages + 18 modals + 7 shared layouts)
- Done:             4
- In progress:      1
- Pending:         42
- Blocked:          0

## Surfaces

### login-page [done] (2026-05-03, 11m)
- Files walked: 3 (page + form component + 2 input wrappers)
- Findings closed: 17 / 17
- By class: hardcoded-design-values(5), missing-error-state(2), focus-state-missing(3), cta-placement-drift(1), motion-inconsistency(2), affordance-clarity(2), type-scale-drift(2)
- Variants generated: 0 (cleanup-only)
- Commits: 17
- Diff: +84 / -126 = -42 lines
- a11y score: 88 → 96
- Visual-regression: target surface only

### orders-list [in-progress] ...
```

### Progress file shape (backend example)

```markdown
# Polish progress

Started: 2026-05-03
Stack: backend-nest
Codebase: <project-root>/api/

## Summary
- Total surfaces:  68 endpoints + 12 middlewares
- Done:             8 endpoints
- In progress:      1 endpoint
- Pending:         59 endpoints + 12 middlewares
- Blocked:          0

## Surfaces

### POST /orders [done] (2026-05-03, 6m)
- Findings closed: 9 / 9
- By class: response-envelope-drift(1), error-contract-drift(2), idempotency-key-missing(1), log-field-drift(3), metric-name-drift(1), openapi-coverage-gap(1)
- Commits: 9
- Diff: +112 / -67 = +45 lines (add-idempotency adds support code)
- OpenAPI delta: 1 endpoint added; 0 breaking changes

### GET /orders [done] ...
```

### Progress file shape (data example)

```markdown
# Polish progress

Started: 2026-05-03
Stack: data
Codebase: <project-root>/db/

## Summary
- Total surfaces:  42 tables + 18 active migrations
- Done:             3 tables
...

### orders [done] (2026-05-03, 4m)
- Findings closed: 6 / 6
- By class: column-naming-drift(2), audit-field-drift(2), timestamp-column-drift(1), nullable-drift(1)
- Commits: 1 (combined into one migration)
- Schema delta: 4 columns renamed; 2 audit columns added; 1 column made NOT NULL with default
```

### Daily workflow

```
Day 1:  /polish                  # first pending surface
Day 2:  /polish                  # next pending
Day 3:  /polish --status         # progress report
        /polish                  # continue
...
```

Overrides:
```
/polish the dashboard           # specific surface
/polish --status                # progress report only
/polish --resume                # pick up in-progress
/polish --reset login-page      # re-run from scratch
/polish --refresh               # RE-SCAN, MERGE into existing progress.md
                                #   - new surfaces → `pending`; missing → `archived`
                                #   - existing rows preserved
/polish --ignore-ledger         # TRULY FRESH SCAN — act as if no polish was ever done
                                #   - Backs up ai/polish/* (ledger, progress, decisions) to *-<iso>.bak.md
                                #   - Re-discovers surface inventory (pages/modals/components for frontend; endpoints for backend; tables for data; screens for mobile)
                                #   - Re-runs the stack-conditional audit on every surface
                                #   - Re-creates the polish report from scratch
                                #   - KEEPS ADR pre-check (intentional design / API / schema / platform deviations preserved)
                                #   - IMPLIES --re-audit semantics
                                #   - Combinable with <scope>: /polish the dashboard --ignore-ledger
                                #   - Use when: design system / API conventions / schema / platform spec changed materially OR you suspect previous polish was incomplete
/polish --re-audit              # IGNORE cached verdicts; re-audit EVERY surface
                                #   - Discards `verified` / `done` rows in ai/polish/ledger.md
                                #   - Re-dispatches the per-surface audit on every row
                                #   - Rows that re-verify clean stay `verified`; rows with reappearing fingerprints flip to `halted` and re-fix in same run
                                #   - Use when: design system / API conventions / schema / platform spec changed OR you suspect drift
                                #   - Combinable with <scope>: /polish the dashboard --re-audit
/polish --restart               # WIPE progress, back up to ai/polish/progress-<iso>.bak.md, start over
                                #   - For "ignore ledger AND re-audit", combine: /polish --restart --re-audit
```

## What you see (output)

Frontend example:

```
Polish complete

Stack:               frontend-vue
Scope:               the dashboard
Findings closed:     31
  hardcoded-design-values:    8 (color/spacing/radius → tokens)
  missing-empty-state:        2
  missing-loading-skeleton:   3
  cta-placement-drift:        4
  type-scale-drift:           5
  motion-inconsistency:       3
  affordance-clarity:         2
  focus-state-missing:        3
  icon-mismatch:              1

Tokens added:        2
Patterns extracted:  1
Variants generated:  3 → user picked "polished"

Commits: 31  Diff: +203 / -489  Tests: 124/124  a11y: 81→94  Visual-regression: target-only  Bundle: -0.4%
```

Backend example:

```
Polish complete

Stack:               backend-nest
Scope:               the orders endpoints
Findings closed:     34
  response-envelope-drift:    8 (unified to {data, meta, errors})
  error-contract-drift:       6 (uniform problem+json shape)
  pagination-drift:           4 (cursor uniformly applied)
  idempotency-key-missing:    5 (Idempotency-Key header on POST/PUT)
  log-field-drift:            7 (userId / orderId / requestId standardized)
  metric-name-drift:          3 (order_<verb>_total naming)
  openapi-coverage-gap:       1

Commits: 34  Diff: +287 / -156  Tests: 298/298  Contract tests: 87/87  OpenAPI: 6 endpoints added; 0 breaking changes
```

Data example:

```
Polish complete

Stack:               data
Scope:               the analytics schema
Findings closed:     19
  column-naming-drift:        5 (snake_case unified)
  type-drift:                 4 (TIMESTAMPTZ unified)
  audit-field-drift:          6 (created_at/created_by/updated_at/updated_by added where missing)
  index-naming-drift:         3 (<table>_<col>_idx pattern)
  soft-delete-drift:          1

Commits: 4 (combined into reversible migrations)  Schema delta: 12 columns renamed; 24 columns added; 6 indexes renamed
```

## What you DON'T see

- Phase numbers, halt files, ADR prompts (unless a genuine blocker requires user input).
- Tier promotions, ledger states.
- "Variant selection menu" unless the audit explicitly opted in for iteration.

All internal. Just results.

## Optional flags

- `--dry-run` — show what would be polished, no edits.
- `--allow-dirty` — proceed with uncommitted changes.
- `--max-parallel=<N>` — cap concurrent dispatch (default: 4).
- `--focus=<list>` — narrow to specific concerns (e.g., `--focus=missing-empty-state` for frontend; `--focus=idempotency-key-missing,log-field-drift` for backend).
- `--exclude=<scope>` — exclude surfaces.
- `--no-iterate` — skip variant generation entirely (frontend only).
- `--direction="<freeform>"` — directional hint for iteration (frontend only).
- `--surface-blockers` — show halted findings explicitly.
- `--stack=<override>` — force a stack interpretation (rarely needed; `PROJECT_KIND` should be set correctly).

## Pre-requisites

- `PROJECT_KIND` is set (`frontend-*`, `backend-*`, `data-*`, `mobile-*`). Halts on `unknown`.
- `_extracted-idioms.md` OR `codebase-profile.md` populated (the convention oracle).
- Mechanical CI green.
- Working tree clean (or `--allow-dirty`).
- Stack-specific:
  - Frontend: Playwright MCP wired (for visual baseline + variant generation; soft-fails to text-only audit if missing).
  - Backend: OpenAPI spec discoverable (for envelope / coverage / drift detection).
  - Data: schema introspection access (a connected DB or migration history).
  - Mobile: per-platform build configurations present.

## Hard rules (internal)

Applied silently per the discipline:
- **Validator gate is mandatory.** After the stack-conditional audit produces its artifact (`_visual-decisions.md` for frontend / `_api-decisions.md` for backend / `_schema-decisions.md` for data / `_platform-decisions.md` for mobile), the agent MUST run `~/.claude/scripts/validate-polish-artifacts.sh`. The validator dispatches per `PROJECT_KIND` and halts if the stack's required evidence blocks are missing (visual baseline + a11y + design-token for frontend; endpoint registry + OpenAPI + envelope + error contract for backend; schema introspection + migration history + column drift for data; per-platform UI tree + iOS HIG + Material 3 for mobile). A failed validator forces the audit to be re-emitted.
- **Conventions are the truth** — design system / API spec / schema / platform spec is the oracle.
- **Closure verbs from the stack's closed vocabulary** — no ad-hoc inventions.
- **Behaviour preserved** — frontend: business logic untouched; backend: API contract preserved (rename happens with deprecation flow, not blind rewrite); data: data preserved (renames via reversible migrations + dual-read window).
- **Re-detect after each fix; gap-count parity**.
- **One commit per finding** for frontend / backend; data findings MAY be combined into a single migration commit when safer.
- **Stack-specific quality gates do NOT regress**:
  - frontend: a11y score, visual-regression on non-target surfaces, bundle size.
  - backend: contract tests, OpenAPI breaking-changes count = 0.
  - data: migration is reversible OR has documented irreversibility ADR.
  - mobile: per-platform smoke green.

User sees results, not the policing.

## Failure modes

- **PROJECT_KIND unset / unknown** → halts with "set PROJECT_KIND via `/setup-project --refine` first".
- **No findings** → "Surface already polished to conventions; nothing to do."
- **Primitive missing** → halts the affected fix; surfaces "/setup-project --refine"; rest continue.
- **Frontend visual-regression collateral** → that fix skips; rest continue.
- **Backend OpenAPI breaking change** → halts; surfaces ADR template.
- **Data irreversible migration** → halts; surfaces ADR template.
- **Iteration declined by user** (frontend) → cleanup-only commits ship; row marks `iteration: skipped`.

## Related (advanced)

For phase-by-phase or specialist control, the existing detailed commands still exist:
- **Frontend**:
  - `/enhance-ui <area>` — pack-level single-area iteration loop (3 variants → pick → verify).
  - `/ui-sweep` — UI/UX whole-project specialist (HTML report, coverage metrics).
  - `/design-review` — read-only design audit.
- **Backend**:
  - `api-consistency-audit` skill — read-only API consistency audit (envelope / errors / pagination / naming).
- **Data**:
  - `/db-audit` — read-only schema/query audit.
  - `/add-migration` — author a single migration.
- **Cross-cutting**:
  - `/align-recheck <scope>` — structural drift only (no creative work).
  - `/align` — convention drift sweep.

`/polish` is the simple-surface entry point. Power users drop down to detailed commands.
