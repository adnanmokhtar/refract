---
description: Consolidate every instance of ONE surface type behind ONE canonical shared implementation, app-wide. Tables, forms, headers, tabs, filters, buttons, validation. Trigger when the ask names the surface type AND the remedy is that every instance of it end up going through that one canonical implementation — extracted, extended, or migrated onto. For six of the seven categories that implementation is ONE shared wrapper; for validation it is the ONE 3-part pipeline (validator composable + error-rendering primitives + API-validation-error mapper), which is why 'standardise form validation everywhere' triggers here even though no single wrapper comes out of it — see § Validation pipeline. 'Unify all tables', 'every page header should look the same', 'standardise form validation everywhere', and the same ask phrased as some-do-X-some-do-Y ('some pages use the shared PageHeader and some roll their own'), where the rolled-own ones must be reconciled INTO the canonical shape — wrapper work /align's closed 21-verb set is barred from doing. Do NOT trigger when a surface noun appears but the wrapper is NOT what changes — a token, a11y rule or naming rule the project already documents is simply applied in place ('our buttons ignore the spacing tokens on the auth pages') — that is /align, which also owns a generic 'make it consistent' carrying no surface-type noun at all. Do NOT trigger to INTRODUCE an axis the project does not have yet (no token defined, no motion system, no missing-state contract) — that is /polish. Not one mechanical a11y class app-wide (/ui-crawl-fix).
compatibility: Frontend stacks only — requires PROJECT_KIND in frontend-*, mobile-web, or mobile-rn, and halts with a redirect to /polish otherwise, mobile-native included. Requires _extracted-idioms.md Wrappers and _extracted-codebase.md Gold standards populated. A Playwright MCP powers the visual-regression gate; without it verification soft-fails to text-only and the parity evidence is weaker.
kind: command
pack: orchestration
version: 1.0.0
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /unify-surfaces [<scope>] [--surfaces=<list>]

## What this does

**Single command. Make every surface of the same TYPE look + behave the same.** Deep multi-agent inventory + canonical-shape decision + wrapper extraction + consumer migration + verify. Whole project or scoped. Multi-day workflow. **Frontend stacks only**.

The user's archetypal ask: *"unify all tables and forms; if a page has a title use one unified header; if a page has tabs they all follow one tab design; every list page's filters move into one unified filter panel; buttons / colors / spacing / styles / interactions all standardised; forms aligned with consistent spacing + layouts + input structures; validation handling unified — frontend validators, error states, required-field handling, API-validation-error display, all consistent across the app."*

That request is **surface-type-typed**, not axis-typed. `/polish` operates per-surface across its 16 axes (tokens / rhythm / motion / etc., closed at 19 verbs — see `commands/polish.md` § Frontend and `templates/packs/ui-ux/rules/ui-principles.md § Axis catalog`); this command operates per-surface-TYPE across the whole project. Both ship; they compose.

The 7 default surface categories:

| Category | What gets unified | Default canonical wrapper signal |
|---|---|---|
| **tables** | List/data table chrome — header row, filter bar position, pagination, empty-state, loading-skeleton, action column, row-density toggle | `_extracted-idioms.md § Wrappers § Tables` OR most-used `<table>` shape across pages |
| **forms** | Form layout — field rhythm, label placement, input width grid, fieldset grouping, submit-row position, dirty-state cue | `_extracted-idioms.md § Wrappers § Forms` OR most-used `<form>` shape |
| **headers** | Page header — title + subtitle + breadcrumb + actions zone, height, spacing, divider, sticky behaviour | `_extracted-idioms.md § Wrappers § PageHeader` OR most-used `h1`+actions block |
| **tabs** | In-page tabs — tab strip, indicator, active state, badge support, overflow / scroll behaviour, tab body container | `_extracted-idioms.md § Wrappers § Tabs` OR most-used tab primitive |
| **filters** | List-page filter panel — search, dropdowns, date-range, chip-display of active filters, clear-all action, position (top vs left vs collapsible) | `_extracted-idioms.md § Wrappers § FilterPanel` OR most-used filter container |
| **buttons** | Button primitive variants — primary / secondary / tertiary / danger / ghost; size scale; icon + text composition; loading / disabled / pressed states; tap-target floor | `_extracted-idioms.md § Wrappers § Button` OR most-used `<button>` shape |
| **validation** | **Specialised pipeline**: frontend validator composable + `<ErrorList>` / `<FieldError>` rendering + required-field convention + API-validation-error mapper that turns server `{field: [msg]}` into field-level errors | extracted as a system, not a single wrapper — see § Validation pipeline |

**Discipline:** MUST read [`templates/governance/core-discipline.md`](../templates/governance/core-discipline.md) before generating code fixes. MUST read [`templates/packs/migration/rules/migration-discipline.md § Reuse-Before-Create`](../templates/packs/migration/rules/migration-discipline.md) — extending a wrapper > forking it; reinventing is a failure mode.

The agent:
1. **Reads the project's wrapper inventory** — `_extracted-idioms.md § Wrappers`, `_extracted-codebase.md § Gold standards`. These are the oracle for what already exists.
2. **For each requested surface category**: inventories every consumer across the codebase, decides the canonical shape, extracts / extends the shared wrapper, migrates every consumer, verifies.
3. **Form-validation runs as a specialised pipeline** — composable + components + mapper as one extracted system; consumers migrated together.
4. **Visual-regression gate after each category** — non-target surfaces must not change pixels.
5. **Iterates variants** for any category whose audit flags "no canonical shape exists, multiple ad-hoc patterns" — generates 2 candidate canonical shapes; user picks; skill applies. Default: skipped (audit picks the most-used shape).

## Stack scope

**Frontend stacks only** (`PROJECT_KIND in {frontend-*, mobile-web, mobile-rn}`). Halts on `backend-*` / `data-*` / `library-*` / `cli-*` with redirect to `/polish` (backend / data axis-consistency) or `/align` (structural drift).

For `mobile-native` (Swift / Kotlin), the surface vocabulary changes (use `platform-conventions-audit` instead) — halts with redirect to `/polish` on a mobile project.

## When to use

- "Unify tables / forms / headers / tabs / filters / buttons / validation across the entire app." → `/unify-surfaces`
- "All list pages should have the same filter panel." → `/unify-surfaces --surfaces=filters`
- "Every page header should look the same." → `/unify-surfaces --surfaces=headers`
- "Standardise form validation everywhere." → `/unify-surfaces --surfaces=validation`
- After several features have shipped with their own ad-hoc table / form / header shapes.
- Pre-launch consolidation pass.
- After a design-system upgrade that introduced new shared wrappers — migrate all consumers.

## When NOT to use

- Per-axis work across one surface type, where the axis value does **not exist yet** (no token defined, no motion system, no missing-state contract) → `/polish` (frontend).
- Per-axis drift across one surface type where the value **already exists** and just has to be applied in place — hard-coded spacing that should be the token the design system already defines, a focus-ring rule already adopted → `/align`. The wrapper is not what changes, so this is enforcement, not consolidation. Same enforce-existing split as [`templates/tool-adapters/_orchestration-sync.md § Command boundary table`](../templates/tool-adapters/_orchestration-sync.md) rows *Design-token drift* and *Accessibility*.
- Single-area iteration with style-variant picking → `/enhance-ui <area>`.
- Specialist whole-project visual audit with HTML report → `/ui-sweep`.
- Read-only audit, no edits → `/design-review` + `/ui-crawl`.
- Pure structural drift across all classes → `/align`.
- One mechanical class app-wide (just contrast, just label-for) → `/ui-crawl-fix <class>`.
- New features → `/add-feature`.
- V1→V2 port → `/migrate`.

## Args

- `<scope>` (optional) — natural-language description OR explicit path. If omitted: whole project.
- `--surfaces=<list>` (optional) — comma-separated subset. Default: `tables,forms,headers,tabs,filters,buttons,validation`. Examples: `--surfaces=tables,filters` / `--surfaces=validation` / `--surfaces=headers,tabs`.

Examples:

```
/unify-surfaces                                        # all 7 categories, whole project
/unify-surfaces --surfaces=tables,filters              # only list-page surfaces
/unify-surfaces --surfaces=validation                  # form-validation pipeline only
/unify-surfaces --surfaces=headers,tabs                # page chrome only
/unify-surfaces --surfaces=buttons                     # button primitive variants only
/unify-surfaces the orders module                      # scoped — only orders pages
/unify-surfaces "the customer-facing pages"            # semantic scope
/unify-surfaces --surfaces=forms src/modules/checkout  # explicit path
```

## What happens internally (silent)

1. **Detect stack** — read `PROJECT_KIND` from `_extracted-codebase.md § Gold standards`. Halts on non-frontend.
2. **Read wrapper inventory** — `_extracted-idioms.md § Wrappers`. Each surface category's canonical wrapper either named here OR will be **promoted from the most-used existing pattern** (via the inventory step below).
3. **Resolve scope** — default whole project; semantic scopes resolve to file globs.
4. **Per requested surface category, in parallel where independent** (foundation order: buttons → headers / tabs / forms / tables / filters → validation; validation depends on forms being unified):
   - **INVENTORY** — find every consumer of this surface type. Detection signals per category in § Detection signals.
   - **DECIDE CANONICAL** — if `_extracted-idioms.md` names a wrapper for this category, that's canonical. Else: cluster consumers by shape similarity, pick the most-used shape, propose it as canonical. If 2+ shapes have similar usage AND none is in idioms → halts on this category (one of the few legitimate halts) with "no clear canonical shape; pick from <N> candidates" and surfaces 2 candidates.
   - **EXTRACT / EXTEND** — if canonical wrapper exists → extend it for any prop / variant the consumer corpus needs that's missing. If it doesn't exist → extract it from the chosen consumer; move to the project's shared wrapper directory; add to `_extracted-idioms.md § Wrappers` so future runs know.
   - **MIGRATE CONSUMERS** — rewrite every non-canonical consumer to use the canonical wrapper. One commit per surface category (not per consumer — cascading rewrite is the point).
   - **VERIFY** — typecheck + lint + scoped tests + visual-regression on non-target surfaces (must not change). Re-detect: every non-canonical consumer must be gone; canonical wrapper consumers count must equal `inventory_count - skipped`.
5. **Validation pipeline** (when `validation` in surfaces list, runs after `forms`) — see § Validation pipeline.
6. **Halt only on genuine blockers**:
   - Multiple equally-used canonical candidates with no `_extracted-idioms.md` tiebreaker → user picks.
   - Visual-regression collateral on a NON-target surface → halts that category's commit; rest continue.
   - Migration would break a public API (e.g., a wrapper exposed from a published library) → halts; surfaces ADR template.
   - Wrapper extraction would require a primitive that doesn't exist (e.g., the project has no design-token system at all) → surfaces "/setup-project --refine to add primitive first"; halts that category.

## Detection signals (per category)

| Category | Inventory signal (frontend stack-conditional) |
|---|---|
| tables | `<table>` / framework's data-table primitive (`<el-table>` / `<DataTable>` / `<v-data-table>` / `<Table>` from a UI lib) / hand-rolled rows-with-scrolling-container shape with header + body |
| forms | `<form>` element + form-state composable / `useForm` / `formState` / `<FormProvider>` boundary |
| headers | first `<h1>` per page-component file + sibling actions slot; sticky-positioned title-bar shape; `<PageHeader>` / `<Header>` / `<TopBar>` already-named wrappers |
| tabs | `<TabView>` / `<v-tabs>` / `[role="tab"]` / `[role="tablist"]` / in-page `<button>` sibling list with conditional `<section>` rendering / array literal of `{label, key}` rendered with v-for|map |
| filters | container near top of list-page with `<input type="search">` + 2+ `<select>` or `<Dropdown>` / `<DatePicker>` siblings; `<FilterPanel>` / `<Filters>` already-named wrappers; URL-query-param-binding form |
| buttons | every `<button>` element + framework's button primitive + `<a class="btn">` / `<a role="button">` shape; cluster by visual variant (primary / secondary / tertiary / danger / ghost) — emerges from class / variant prop |
| validation | every `validate()` call / `useForm()`-style return / Zod / Yup / Joi / Vuelidate / Formik / RHF schema declaration; every `<*Error>` / `<ErrorMessage>` rendering; every `error.response.data.errors` mapper; every `:rules=` / `validate=` / `:state=` prop on a form input |

These signals are stack-agnostic at the level of intent; the concrete tag / function names come from `_extracted-idioms.md`.

## Validation pipeline (special-cased)

The `validation` category does NOT extract a single wrapper. It extracts a **3-part system**:

1. **Frontend validator composable** — single source of truth for declaring per-field rules. Project-conventional name from `_extracted-idioms.md` (e.g., `useFormValidation()` / `useValidation()` / `useForm()` — extends the project's existing form library or wraps it). One declarative API for all forms.
2. **Error rendering primitives** — `<ErrorList>` / `<FieldError>` (whichever the project's idioms name). Single rendering convention: where errors appear relative to the input (below, right-of, tooltip), error tone (red text + icon), required-field marker convention (asterisk + accessible-text), error-summary placement at form top.
3. **API-validation-error mapper** — single function that takes a server error response (the project's specific shape — `{errors: {field: [msg]}}` / `{message, errors}` / Rails/Laravel 422 / RFC-7807) and returns field-level errors that the validator composable can attach to the form. Lives next to the API client, registered as a global response interceptor where the project supports it.

**Migration order** (ensures consumers always have a working pipeline):
1. Add the 3 primitives to the shared layer (composable + components + mapper).
2. Wire the API mapper into the project's HTTP-client-of-record (axios interceptor / fetch wrapper / `$api` plugin) so non-migrated forms still get sane error display.
3. Migrate forms one at a time — each migration removes the form's bespoke validator + bespoke error rendering + bespoke server-error handling, replacing all three with the unified pipeline.
4. After all forms migrated: scan for residual bespoke validators / error renderers / server-error mappers; halt the category if any remain.

**Halt conditions specific to validation**:
- Project uses 2+ form libraries (RHF + Formik + bespoke) → surfaces "pick one form library first" with ADR template; halts the category.
- API error shape is inconsistent across endpoints → halts; routes to `/polish` (backend `unify-error-contract` verb) for the API side first; surfaces blocked.
- A form's validation rules are server-only (no frontend mirror) → preserves server-only behaviour, attaches API errors via the mapper; does NOT invent client-side rules.

## Progress tracking (multi-day workflow)

Single source of truth: **`ai/unify-surfaces/progress.md`**.

### How it works

- **First run** → builds per-category inventory, writes progress file (each category `pending` with consumer count). Runs first category.
- **Subsequent runs** → reads progress file, picks next `pending` category. Already-`done` categories skipped.
- **`/unify-surfaces --status`** → read-only progress report; no work done.

### Progress file shape

```markdown
# Unify-surfaces progress

Started:   2026-05-11
Stack:     frontend-vue
Codebase:  <project-root>/src/
Scope:     whole project

## Summary
- Categories requested:  7
- Done:                  3 (buttons, headers, tabs)
- In progress:           1 (forms)
- Pending:               3 (tables, filters, validation)
- Blocked:               0

## Categories

### buttons [done] (2026-05-11, 18m)
- Inventory:               312 consumers across 47 files
- Canonical:               <BaseButton variant="primary|secondary|tertiary|danger|ghost"> (extracted from src/shared/ui/BaseButton.vue, extended with `tertiary` + `ghost` variants)
- Consumers migrated:      298 / 312 (14 skipped: 8 inside legacy admin pages outside scope; 6 require a custom variant — surfaced for user)
- Wrappers reused:         1 (BaseButton — extended)
- Wrappers extracted:      0
- Idioms updated:          _extracted-idioms.md § Wrappers § Button (variant list grew from 3 → 5)
- Commits:                 1 (cascade-rewrite — `unify-component(buttons)`)
- Diff:                    +148 / -1,247 = -1,099 lines
- Tests:                   124/124  Visual-regression: target-only  Bundle: -0.6%
- a11y delta:              +4 (focus-ring uniform; aria-label injected on icon-only)

### headers [done] (2026-05-11, 11m) ...
### tabs [done] (2026-05-11, 9m) ...
### forms [in-progress] ...
### tables [pending] ...
### filters [pending] ...
### validation [pending] ...
```

### Daily workflow

```
Day 1:  /unify-surfaces                         # foundation: buttons + headers + tabs
Day 2:  /unify-surfaces                         # forms
Day 3:  /unify-surfaces                         # tables + filters
Day 4:  /unify-surfaces                         # validation pipeline
Day 5:  /unify-surfaces --status                # green across all 7
```

Overrides:

```
/unify-surfaces --surfaces=validation           # specific category
/unify-surfaces --status                        # progress only
/unify-surfaces --resume                        # pick up in-progress
/unify-surfaces --reset forms                   # re-run from scratch
/unify-surfaces --refresh                       # RE-SCAN, MERGE into existing progress.md
                                                #   - new consumers → counted; missing → archived
                                                #   - `done` categories preserved
/unify-surfaces --re-audit                      # IGNORE cached verdicts; re-audit every category
                                                #   - rows that re-verify clean stay `done`
                                                #   - rows with reappearing non-canonical consumers flip to `halted` and re-fix in same run
                                                #   - Use when: a new feature merged with bespoke surfaces
/unify-surfaces --restart                       # WIPE progress, back up to ai/unify-surfaces/progress-<iso>.bak.md, start over
/unify-surfaces --ignore-ledger                 # TRULY FRESH SCAN — act as if no unification ever happened
                                                #   - Backs up ai/unify-surfaces/* to *-<iso>.bak.md
                                                #   - Re-discovers per-category inventory from source
                                                #   - Re-runs the 5-step pipeline on every category
                                                #   - KEEPS ADR pre-check (intentional non-canonical surfaces preserved)
                                                #   - IMPLIES --re-audit
```

## What you see (output)

Whole-project example:

```
Unify-surfaces complete

Stack:               frontend-vue
Scope:               whole project (src/)
Categories:          7 / 7 done

  buttons       canonical=<BaseButton>(5 variants)        298 / 312 consumers migrated
  headers       canonical=<PageHeader>(extracted)          47 /  47 consumers migrated
  tabs          canonical=<RouteTabs>(extracted)           14 /  14 consumers migrated
  forms         canonical=<BaseForm>(extended)             31 /  31 consumers migrated
  tables        canonical=<BaseDataTable>(extended)        24 /  24 consumers migrated
  filters       canonical=<FilterPanel>(extracted)         22 /  22 consumers migrated
  validation    pipeline=useFormValidation+ErrorList+apiErrorMapper  31 forms wired

Wrappers extracted:        4 (PageHeader, RouteTabs, FilterPanel, ErrorList)
Wrappers reused / extended: 3 (BaseButton, BaseForm, BaseDataTable)
Variants removed:          18 ad-hoc shapes deleted
Idioms updated:            _extracted-idioms.md § Wrappers (7 entries refreshed)

Commits: 7 (one per category)  Diff: +2,148 / -5,492 = -3,344 lines
Tests: 487/487  Visual-regression: target-only  Bundle: -2.1%  a11y: 81 → 96
Skipped (surfaced for user): 14 buttons inside legacy admin pages (outside scope)

Not validated:  visual-regression on the 14 skipped legacy admin pages (outside scope)
Risks:          BaseForm extension adds a `dense` prop — 31 consumers re-render once on mount; profile if any list page feels slower
Revert:         git revert <category-sha>  (one cascade commit per category — revert per category)
```

Validation-only example:

```
Unify-surfaces complete

Stack:               frontend-vue
Scope:               --surfaces=validation
Categories:          1 / 1 done

  validation    pipeline = useFormValidation + <ErrorList> + apiErrorMapper

Pipeline parts shipped:
  - useFormValidation()   composable at src/shared/composables/useFormValidation.ts (NEW)
  - <ErrorList>           component at src/shared/ui/ErrorList.vue (NEW)
  - <FieldError>          component at src/shared/ui/FieldError.vue (NEW)
  - apiErrorMapper        at src/shared/api/mapApiErrors.ts (NEW)
  - axios interceptor     at src/api/client.ts (wired)

Forms migrated:            31 / 31
Bespoke validators removed: 11
Bespoke error renderers removed: 18
Bespoke server-error handlers removed: 14
Required-field convention:  asterisk + sr-only "required" text (uniform)

Commits: 1 (cascade-rewrite — `unify-validation-pipeline`)
Diff: +412 / -1,873 = -1,461 lines
Tests: 134/134 (added 9 new tests for the composable + mapper)
a11y: 88 → 94 (every error now wired via aria-describedby + role=alert)

Not validated:  none — full suite + visual-regression on all routes ran
Risks:          server-error mapping assumes the {errors: {field: [msgs]}} API shape — confirm with backend before deploy
Revert:         git revert <sha>  (single cascade commit)
```

## What you DON'T see

- Phase numbers, halt files, ADR prompts (unless a genuine blocker requires user input).
- Tier promotions, ledger states.
- Per-consumer commits (cascade-rewrite ships as one commit per category — that's the point of unification).

All internal. Just results.

## Optional flags

- `--surfaces=<list>` — subset; default all 7.
- `--dry-run` — show what would be unified, no edits. Reports per-category inventory + canonical-shape proposal + migration count.
- `--allow-dirty` — proceed with uncommitted changes.
- `--max-parallel=<N>` — cap concurrent category dispatch (default: 3 — categories have dependency edges; not all parallelisable).
- `--exclude=<scope>` — exclude paths from inventory.
- `--exclude-consumer=<glob>` — exclude specific consumers from migration (e.g., legacy pages slated for deletion).
- `--surface-blockers` — show halted categories explicitly.
- `--no-iterate` — never present canonical-shape variants; always pick most-used. Default is to halt + ask only when usage is ambiguous.
- `--canonical=<category>=<wrapper-path>` — force canonical wrapper for a category (overrides `_extracted-idioms.md` and inventory). Repeatable. Example: `--canonical=tables=src/shared/ui/BaseDataTable.vue --canonical=headers=src/shared/ui/PageHeader.vue`.
- `--keep-ad-hoc=<glob>` — explicitly preserve ad-hoc surfaces matching the glob (e.g., a one-off marketing page that intentionally diverges).
- `--validation-library=<name>` — when 2+ form libraries are present, pick one. Halts otherwise.

## Pre-requisites

- `PROJECT_KIND` is `frontend-*` (or `mobile-web` / `mobile-rn`). Halts otherwise.
- `_extracted-idioms.md § Wrappers` populated. If missing → halts with "/setup-project --refine to extract idioms first".
- `_extracted-codebase.md § Gold standards` populated.
- Mechanical CI green.
- Working tree clean (or `--allow-dirty`).
- Playwright MCP wired (for visual-regression gate). Soft-fails to text-only verification if missing — but visual-regression is the strongest evidence that non-target surfaces didn't shift.

## Final report contract

Every run that produces `ai/unify-surfaces/final-report.md` MUST end with an **`## Actionable next steps`** section per `~/.claude/templates/snippets/actionable-next-steps.md`. Every skipped consumer + halted category + deferred decision gets one paste-ready follow-up command — comment line (WHAT + WHY + scope) + exact command + sorted by leverage. The validator's `check_actionable_next_steps` halts when the section is missing OR when a deferral is described in prose without a corresponding paste-ready command line. Each line cites the relevant follow-up: `/enhance-ui` for surfaces needing visual iteration after unification; `/polish --focus=<verb>` for residual axis drift; `/ui-crawl-fix` for any wrapper-level mechanical findings the migration surfaced.

## Hard rules (internal)

Applied silently per the discipline:

- **Reuse-Before-Create.** Before extracting a new wrapper, check `_extracted-idioms.md § Wrappers`. If something close exists → extend it; do NOT fork a parallel wrapper. The migration-pack `Reuse-Before-Create` rule is the canonical statement; this command enforces it as a hard halt — extracting a duplicate where a shared wrapper exists fails the verify gate (`scripts/validate-unify-surfaces-artifacts.sh § check_reuse_before_create`).
- **One commit per category, not per consumer.** Cascade-rewrite is the point. Per-consumer commits hide the unification.
- **Behaviour preserved.** Each consumer migration is structural — the same form fields submit the same data; the same table rows render the same content; the same buttons fire the same handlers. Functional changes happen via separate `/enhance-ui` / `/polish` runs.
- **Visual-regression gate after each category.** Non-target surfaces must not change pixels. A category whose migration causes off-target visual diff halts the commit; the residual is surfaced for triage.
- **Idioms updated as part of the commit.** Every category that extracts / extends a wrapper updates `_extracted-idioms.md § Wrappers` in the same commit so future runs (and future agents) inherit the canonical decision.
- **No new abstractions beyond the canonical implementation.** A category extracts ONE wrapper (or extends ONE existing wrapper) — `validation` is the one category whose canonical implementation is the 3-part pipeline instead, and it extracts exactly those three parts, never a fourth. No "while I'm here, also extract a sub-wrapper" — that's `/enhance-ui` territory.
- **Validation pipeline ships as a system, not as parts.** The composable + components + mapper land in one commit; consumers migrate in subsequent commits using the now-available pipeline.
- **Final report MUST end with paste-ready next steps.** *(Mechanical — `scripts/validate-unify-surfaces-artifacts.sh § check_actionable_next_steps`.)*
- **Honesty clause in the summary block is mandatory.** The three lines `Not validated:` / `Risks:` / `Revert:` close every run summary — name what did NOT run (or `none — <what fully ran>`), residual risks (or `none identified`), and the exact revert command (per-category cascade commits). Omitting the negative space is the Trusted Summary failure mode applied to the run report.

User sees results, not the policing.

## Failure modes

- **Stack not frontend** → halts; redirects to `/polish` (backend / data) or `/align` (cross-cutting drift).
- **`_extracted-idioms.md § Wrappers` missing** → halts; surfaces `/setup-project --refine`.
- **No clear canonical shape** (multiple equally-used patterns, no idioms tiebreaker) → halts that category; surfaces 2 candidates; `--no-iterate` skips the prompt and picks alphabetically.
- **Public-API wrapper rename** would break a published library → halts; surfaces ADR template.
- **Visual-regression collateral on non-target surface** → that category's commit reverts; rest continue.
- **Validation: multiple form libraries present** → halts; surfaces "pick one via `--validation-library=<name>` or ADR".
- **Validation: API error shape inconsistent across endpoints** → halts; routes to `/polish --focus=unify-error-contract` (backend) first.

## Related (advanced)

For finer control, the existing detailed commands still exist:

- `/polish` (frontend) — per-axis whole-project polish (tokens / rhythm / motion / states / type-scale / etc.). Sibling. They compose: `/unify-surfaces` first (consolidate the wrappers), then `/polish` (polish each wrapper to spec).
- `/enhance-ui <area>` — pack-level single-area iteration loop with style-variant picking. Use after unification to refine a specific canonical wrapper visually.
- `/ui-sweep` — UI/UX whole-project specialist (HTML report, coverage metrics). Use to measure cross-surface consistency BEFORE running `/unify-surfaces`, and AFTER to verify the metric improved.
- `/ui-crawl` + `/ui-crawl-fix` — Playwright cross-route crawler + wrapper-level auto-fixer. Use after unification to mass-fix mechanical findings (contrast / button-name / label-for) on the now-unified wrappers.
- `/align` — convention drift sweep across all classes. Sibling but different: `/align` closes any `duplicated-surface-styles`; `/unify-surfaces` is type-typed and does the wrapper-extraction half explicitly.
- `/design-review` — read-only design audit. Use before `/unify-surfaces` to surface the ad-hoc surfaces that need unification.

`/unify-surfaces` is the simple-surface entry for "make the same surface look the same everywhere". Power users drop down to detailed commands for fine control or post-unification polish.
