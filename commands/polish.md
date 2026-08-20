---
description: Introduce finish the project does not have yet, on the axis its PROJECT_KIND dictates. Visual hierarchy and missing states, API envelope and error contract, schema consistency, or platform conventions. Trigger on 'polish the API surface', 'polish the dashboard', 'pre-launch consistency sweep'. Do NOT trigger to snap values to tokens that ALREADY exist — /align enforces, this introduces. Not one surface with variant picking (/enhance-ui), not responsive or dark-mode drift (outside the closed 19-verb set), not read-only audits (/design-review).
compatibility: Requires PROJECT_KIND set and halts on unknown. Per kind — frontend wants a Playwright MCP for visual baselines and soft-fails to a text-only audit without it; backend wants a discoverable OpenAPI spec; data wants schema introspection via a live DB or migration history; mobile wants per-platform build configs. A missing one narrows the pass rather than blocking it.
kind: command
pack: orchestration
---

# /polish [<scope>]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../templates/snippets/plan-flag.md). `/polish <scope> --plan` runs the stack-conditional diagnosis + detector scan, writes the ranked polish plan to `.claude/plans/`, and exits before any edit. Execute it later with `/execute-plan <file>` (or hand it to any tool).

## What this does

**Single command. Make the project's surface look + feel finished.** Deep multi-agent diagnosis + creative cleanup. Whole project or scoped. Multi-day workflow. **Stack-conditional** — dispatches detectors + closure verbs based on `PROJECT_KIND`.

What "polish" means depends on the stack:

| Stack | Focus | Example findings |
|---|---|---|
| `frontend-*` | Visual + UX consistency | Missing empty/loading/error states; CTA placement drift; hardcoded colors → tokens; type-scale drift; motion inconsistency; focus state missing |
| `backend-*` | API consistency + observability uniformity | Response envelope drift; error-contract drift; pagination drift; idempotency-key missing; log-field naming drift; metric/trace naming drift; OpenAPI gaps |
| `data-*` | Schema + migration consistency | Column naming drift (snake/camel); type-choice drift (VARCHAR vs TEXT for same concept); index-naming drift; audit-field gaps; migration pattern drift; soft-delete coverage |
| `mobile-*` | Frontend polish + platform conventions | All frontend findings + iOS HIG conformance + Material spec conformance + per-platform surface adaptations |

**Discipline:** MUST read [`templates/governance/core-discipline.md`](../templates/governance/core-discipline.md) before generating code fixes.

The agent:
1. **Reads the project's design / API / schema / platform conventions** — `_extracted-idioms.md`, `ai/conventions.md`, `ai/architecture.md`, `_extracted-codebase.md § Gold standards`. These are the oracle for what "polished" means in this codebase.
2. **Audits every relevant surface** — pages/modals/dashboards (frontend); endpoints/handlers/responses (backend); tables/migrations/queries (data); screens + platform manifests (mobile). **On frontend, a chart / data-viz and a data table ARE surfaces** — not decoration to skip. A polished dashboard whose cards are finished but whose chart still has muddy series colours, an illegible legend, no no-data state, and a table with no zebra / hover / empty state is *not* polished. The 19 verbs apply to them (see the frontend branch note).
3. **Closes drift mechanically** — hardcoded values → tokens / shared types / canonical names. Same closure-verb grammar across stacks; only the targets change.
4. **Adds creative polish in parallel** — empty/loading/error states (frontend); idempotency keys + standard error envelopes (backend); audit columns + soft-delete (data); platform-conforming surfaces (mobile).
5. **Iterates variants** for frontend surfaces flagged "visually weak" (3 style variants generated; user picks; skill applies — only when audit explicitly opts in). Backend / data / mobile do NOT iterate; they unify-or-not.

## Stack-conditional detector dispatch

### Frontend (`frontend-*`)

**Closure-verb skill (the spec): `ui-design-sweep` (ui-ux pack).** The frontend half of `/polish` operates from this skill's closed 19-verb vocabulary — sibling to `api-consistency-audit` (backend, 15 verbs) and `schema-consistency-audit` (data, 12 verbs). Per-verb fingerprint + procedure + verify + WCAG / iOS HIG / Material citation lives in the skill; the validator (`scripts/validate-polish-artifacts.sh § check_frontend_verb_vocabulary`) rejects any `closure_verb:` outside this set. The validator's `UI_DESIGN_SWEEP_VERBS` array is the authoritative count (19).

Detector skills (feed findings into the closure verbs): `design-token-audit` → `consolidate-tokens` / `extract-token`; `motion-audit` → `normalize-motion`; `a11y-quick-check` → `lift-contrast` / `align-focus-ring` / `clarify-affordance` / `expand-tap-target`; `design-iterate` → visual variant generator (used by `--with-iterate`, NOT a closure verb).

Axis catalog (16 axes; see `templates/packs/ui-ux/rules/ui-principles.md § Axis catalog` for heuristics): tokens · wrappers · patterns · hierarchy · type-scale · rhythm · density · states · contrast · focus · iconography · motion · tap-target · cta · affordance · surface.

The 19 closure verbs (cross-reference: `templates/packs/ui-ux/skills/ui-design-sweep/SKILL.md § The 19 closure verbs`):
- **tokens / wrappers / patterns**: `consolidate-tokens`, `extract-token`, `unify-component`, `extract-pattern`
- **hierarchy / type / rhythm / density**: `normalize-hierarchy`, `apply-type-scale`, `tighten-rhythm`, `simplify-density`
- **states**: `wire-empty-state`, `wire-loading-state`, `wire-error-state`
- **contrast / focus**: `lift-contrast`, `align-focus-ring`
- **iconography / motion / tap-target**: `unify-iconography`, `normalize-motion`, `expand-tap-target`
- **cta / affordance / surface**: `unify-cta-placement`, `clarify-affordance`, `normalize-surface`

**Boundary vs `/align` (per finding).** When a frontend finding is **"hardcoded value that should map to an EXISTING token"** or **"a11y drift from an existing rule"**, that is mechanical enforcement of an existing primitive → **defer to `/align`** (it routes the value to the shared primitive, no creative work). `/polish` keeps the *creative / finish* verbs: extract a NEW token (`extract-token` / `extract-pattern`), wire missing empty/loading/error states, and the rhythm / hierarchy / motion / cta / surface verbs that introduce finish. Rule of thumb: **`/align` enforces what already exists; `/polish` introduces NEW finish.** The canonical split lives in the boundary table in [`_orchestration-sync.md`](../templates/tool-adapters/_orchestration-sync.md).

**Framework component-library controls need explicit overrides — the token/theme layer does NOT reach them.** A design-token file styles the project's own elements; it does not style the internals of a component library — PrimeVue (`SelectButton`, `Calendar`, `InputText`, `Dropdown`), MUI, Ant, Vuetify, Radix/shadcn render with their DEFAULT theme unless you write `:deep()` / `::v-deep` / theme-token overrides for their inner classes (`.p-button`, `.p-inputtext`, `.p-highlight`, …). The **filter / control bar** (date pickers, segmented toggles, selects, action buttons) is usually built from these, so `consolidate-tokens` / `lift-contrast` / `normalize-surface` must be applied to the control's override layer explicitly — "the tokens are defined, the controls will follow" is false; they stay default until overridden. Treat each library control on the surface as a component to finish, not chrome that themes itself.

**Charts / data-viz + data tables are in-scope surfaces (the existing 19 verbs finish them — no new verb).** A chart-library chart (Chart.js / ECharts / Recharts / Nivo / D3) holds its colours, grid, axis, font and tooltip styling in its OWN config object, NOT in design tokens — so a token-driven sweep silently skips it, which is exactly why a "polished" dashboard ships with an unpolished chart. Same for a shared `<DataTable>`: it's *composed*, not re-implemented, so its header/row/zebra/hover/empty styling never gets touched. Fix: treat the chart config and the table wrapper as first-class surfaces and route the existing verbs onto them — `consolidate-tokens` (series/axis/grid colours → the project's token values, set inside the chart config), `wire-empty-state` / `wire-loading-state` / `wire-error-state` (real no-data / skeleton / load-fail states — a chart with zero rows must not render an empty canvas; a table must not render a bare header), `lift-contrast` (legend + axis labels + table text ≥ AA), `normalize-motion` (enter/update transitions consistent with the system), `normalize-surface` / `tighten-rhythm` (card padding, table density). This is finish *within* the system, not a re-theme (that's `/redesign` + `/art-direct`). No new closure verb is added — the closed set stays at 19.

**Responsive + theme-mode are out of scope (documented deferral).** The closed 19-verb set intentionally does NOT cover responsive / breakpoint drift or dark-mode / theme-mode drift. There is no `normalize-responsive` or `unify-theme-mode` verb — those concerns defer to **`/enhance-ui`** (single-area iteration with breakpoint + theme handling). Keeping the set closed at 19 preserves the clean per-verb verify contract; adding responsive/theme verbs would require viewport-matrix + theme-matrix verify steps that belong to the iteration loop, not the closure sweep.

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
- **Enforcing EXISTING tokens / a11y rules / ui-state contracts (mechanical drift → shared primitive, no creative work) → `/align`.** Canonical split: **`/align` enforces what already exists; `/polish` introduces NEW finish.** A "hardcoded value that should map to an EXISTING token" or "a11y drift from an existing rule" is `/align` territory; `/polish` keeps the creative/finish verbs (extract NEW tokens, wire empty/loading/error states, rhythm/hierarchy/motion/cta). See the boundary table in [`_orchestration-sync.md`](../templates/tool-adapters/_orchestration-sync.md).
- Responsive / breakpoint drift + dark-mode / theme-mode drift → `/enhance-ui` (NOT in the `/polish` closed verb set — see "Responsive + theme-mode" note in the frontend branch).
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

Not validated:  cross-browser pass (Playwright ran chromium-only)
Risks:          none identified — visual-only changes, logic untouched
Revert:         git revert <first-sha>..<last-sha>  (one commit per finding)
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

Not validated:  consumer smoke against the deprecated envelope aliases (no consumer repo in env) — verify before alias removal
Risks:          log-field renames may break saved dashboard queries — check Grafana/Kibana saved searches
Revert:         git revert <first-sha>..<last-sha>  (one commit per finding)
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

Not validated:  dual-read window not yet closed — old column names still served until <date>
Risks:          renames touch 3 downstream ETL jobs — coordinate before closing the window
Revert:         each migration ships a tested down() — bun run migrate:down <id>
```

## What you DON'T see

- Phase numbers, halt files, ADR prompts (unless a genuine blocker requires user input).
- Tier promotions, ledger states.
- "Variant selection menu" unless the audit explicitly opted in for iteration.

All internal. Just results.

## Optional flags

- `--dry-run` — show what would be polished, no edits.
- **`validate-polish-artifacts.sh` (hooks / CI)** — run after the stack-conditional audit; exits non-zero on failure. Set env `QUIET=1` for quieter output (script-supported). **Deliberate design: the validator is env-var-only — `QUIET`, `POLISH_DIR`, `PROJECT_KIND` — and has NO CLI flags.** There is no `--strict` because every failure is already blocking (no soft/advisory tier to gate); quieting is the only knob, exposed as `QUIET=1` so the same invocation works identically in a hook, in CI, and from a shell.
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

## Final report contract

Every run that produces `ai/polish/final-report.md` MUST end with an **`## Actionable next steps`** section per `~/.claude/templates/snippets/actionable-next-steps.md`. Every deferred / out-of-scope / "consider doing this" finding gets one paste-ready follow-up command — comment line (WHAT + WHY + scope) + exact command + sorted by leverage. The validator's `check_actionable_next_steps` reports a failure when the section is missing OR when a deferral is described in prose without a corresponding paste-ready command line — surfaced only when the agent runs `validate-polish-artifacts.sh` (agent-side discipline; the run does not invoke it automatically). Each line cites the relevant closure verb via `--focus=<verb>` when applicable (frontend → `ui-design-sweep` 19-verb set; backend → `api-consistency-audit` 15-verb set; data → `schema-consistency-audit` 12-verb set; mobile → `platform-conventions-audit` verbs).

## Hard rules (internal)

Applied silently per the discipline:
- **Validator run is agent-side discipline (not an automated gate).** After the stack-conditional audit produces its artifact (`_visual-decisions.md` for frontend / `_api-decisions.md` for backend / `_schema-decisions.md` for data / `_platform-decisions.md` for mobile), the agent SHOULD run `~/.claude/scripts/validate-polish-artifacts.sh` and act on its result — the multi-agent run does NOT invoke the validator, so nothing halts the run automatically. The validator dispatches per `PROJECT_KIND` and reports a failure if the stack's required evidence blocks are missing (visual baseline + a11y + design-token for frontend; endpoint registry + OpenAPI + envelope + error contract for backend; schema introspection + migration history + column drift for data; per-platform UI tree + iOS HIG + Material 3 for mobile). On a reported failure the agent should re-emit the audit before advancing.
- **Final report MUST end with paste-ready next steps.** *(Checked by `validate-polish-artifacts.sh § check_actionable_next_steps` — agent-side; surfaced only when the agent runs the validator.)* Per `actionable-next-steps.md` snippet contract; reports a failure when missing or when deferrals are described without commands.
- **Honesty clause in the summary block is mandatory.** The three lines `Not validated:` / `Risks:` / `Revert:` close every run summary — name what did NOT run (or `none — <what fully ran>`), residual risks (or `none identified`), and the exact revert path (git range, or migration `down()` for data). Omitting the negative space is the Trusted Summary failure mode applied to the run report.
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
