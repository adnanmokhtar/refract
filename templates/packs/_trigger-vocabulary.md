# Trigger vocabulary (authoritative)

Every `_topics.md` declares `triggers:` — a boolean expression over signals the Phase 2 orchestrator (`extract-codebase-overview`) records in `.claude/_extracted-codebase.md`. This file is the **single canonical list** of valid trigger names. Topic specs MUST use names from here; pack maintainers add new ones by editing this file + the orchestrator's Step 1-12.

Boolean ops in topic specs: `AND`, `OR`, `NOT`. Default join across multiple keys = AND. List operands: `signal_confirmed_any`, `signal_confirmed_all`.

**Where the `*_detected` answers come from.** `scripts/detect-signals.sh` computes every
`*_detected` name in this file from the repository on disk and writes them to
`<target>/.claude/_detected-signals.md` (a markdown table plus a `name=yes|no` machine block).
`run-preflight.sh` runs it at STEP 0.4, so the answers exist before any pack decision is made.

> **Why this is written down.** Measured 2026-08-23: **29 of the 32 `*_detected` triggers below
> had no producer anywhere in the repo**, so every topic gated on one of them could never fire,
> on any project — and `scripts/lint-setup-contracts.sh` Rule 4, the ratchet for exactly that,
> had all 29 recorded in its baseline, so nothing turned red. The two that *had* been fixed
> lived only in `templates/appendices.md`, a Tier-3 COLD doc no script executes: correct, and
> unreachable. **Adding a name here without an extractor in `scripts/detect-signals.sh` puts it
> straight back into that state** — Rule 4 fails the build if you do, and
> `scripts/test-detect-signals.sh § 1` checks the two lists against each other in both
> directions.

---

## Always-applies

- `always: true` — apply unconditionally. Used for cross-cutting tracks (security, code-quality, learning).

## Stack / framework

- `primary_framework_detected` — top-level backend framework identified (NestJS / Django / Rails / etc.).
- `primary_frontend_framework_detected` — top-level frontend framework (Vue / React / Angular / Nuxt / Next / Svelte).
- `mobile_framework_detected` — React Native / Flutter / native iOS/Android.
- `native_bridge_present` — mobile project ships custom native-bridge code (iOS Objective-C/Swift OR Android Kotlin/Java OR Flutter platform channels OR React Native TurboModules) under `ios/` / `android/` / a `*-native-modules` package.
- `language: <name>` — e.g., `language: typescript`. Use sparingly (prefer framework triggers).
- `package_manager_detected` — bun / pnpm / npm / yarn / pip / cargo / etc.
- `build_tool_detected` — esbuild / vite / webpack / turbo / nx / rollup.

## Repository shape

- `repo_shape: <single|monorepo|workspace>` — from manifest detection.
- `service_count_above_<N>` — count of deployable apps (e.g., `service_count_above_1`).
- `module_per_feature_layout` — modules organized as `<feature>/{controller,service,repo}` rather than flat MVC dirs.

## Data layer

- `orm_detected` — TypeORM / Prisma / SQLAlchemy / ActiveRecord / Eloquent / Drizzle / Sequelize / Mongoose.
- `migration_tool_detected` — typeorm migrations / prisma / alembic / rails / phinx / etc.
- `migration_dir_detected` — `prisma/migrations/` or `database/migrations/` or `db/migrate/`.
- `entity_count_above_<N>` — count from Step 6.
- `codebase_has_base_classes` — at least 1 class with ≥3 extenders found in Step 5.

## API layer

- `api_surface_detected` — controllers/routers/views detected in Step 7.
- `api_client_detected` — frontend has an API-client module (axios wrapper / fetch wrapper / generated SDK).
- `controller_pattern_detected` — files matching `*controller*` / `*router*` / `*view*` exist with route registration.
- `dto_pattern_detected` — class-validator / pydantic / marshmallow / zod / similar declarative validation in use.

## Auth

- `auth_scheme_detected` — JWT / session / OAuth / API-key middleware found in Step 7.

## Cross-cutting signals (from Step 9 — must be CONFIRMED, not guessed)

- `signal_confirmed: <name>` — single signal must be present with high confidence.
- `signal_confirmed_any: [<name1>, <name2>, ...]` — at least one must match.
- `signal_confirmed_all: [<name1>, <name2>, ...]` — all must match.

Valid signal names (must match `~/.claude/templates/domains/<name>/`):
`ai`, `webhook`, `multi-tenant`, `payment`, `real-time`, `event-sourced`, `file-upload`, `search`, `feature-flags`, `notifications`, `background-jobs`, `compliance`, `workflow-orchestration`, `data-pipeline`, `analytics`, `reporting`.

> This list names the signals a topic spec may currently gate on — it is a subset of
> `templates/domains/_registry.md`, not a mirror of it. A domain folder exists for every key here,
> but the reverse does not hold: a domain is only usable as a trigger once Appendix A
> (`templates/appendices.md` § Appendix A) emits a detection result for it and the Phase 2
> orchestrator's Step 9 records it. Adding a key here without that detection step produces a
> trigger no extractor emits — dead code, per the hard rules below.

## Observability

- `logger_lib_detected` — structured logger (pino / winston / loguru / log4j / zap / etc.).
- `metrics_lib_detected` — prometheus / statsd / datadog / etc.
- `tracer_lib_detected` — OpenTelemetry / Jaeger / Zipkin / etc.

## Tests

- `test_framework_detected` — Jest / Vitest / Pytest / RSpec / Go test / etc.

## i18n / locale

- `i18n_lib_detected` — nestjs-i18n / vue-i18n / next-intl / django.utils.translation / etc.
- `rtl_locale_detected` — repo has Arabic / Hebrew / Farsi locale files OR README mentions RTL.

## Frontend extras

- `forms_lib_detected_OR_form_components_present` — VeeValidate / Formik / React Hook Form / Form.io / etc., OR sample form components found.
- `ssr_capable_framework_detected` — Nuxt / Next / SvelteKit / Remix / Astro.
- `ssr_enabled` — framework supports SSR AND project config does not opt-out (Nuxt SSR mode, Next non-static).
- `dark_mode_capability_detected` — `dark:` Tailwind class / theme provider supports light+dark.
- `multi_theme_signal_detected` — repo has multi-theme infrastructure (theme variants, theme switcher).
- `animation_lib_detected_OR_motion_components_present` — framer-motion / motion / GSAP / vue-transition usage.

## Infra / deploy

- `dockerfile_detected` — `Dockerfile` at root or in apps.
- `dockerfile_or_k8s_detected` — Dockerfile OR k8s manifests.
- `k8s_detected` — apiVersion-headed YAML manifests OR Helm charts.
- `dockerfile_or_k8s_or_terraform_detected` — any infra-as-code artifact.
- `terraform_detected` — `*.tf` files.
- `ci_config_detected` — `.github/workflows/*` / `.gitlab-ci.yml` / `.circleci/config.yml` / `bitbucket-pipelines.yml`.
- `ci_or_dockerfile_detected` — convenience union.
- `container_target_likely` — Dockerfile present OR build output is server-side OR deploy mention in README.

## VCS / external

- `vcs_detected` — `.git/` exists.
- `external_dependency_count_above_<N>` — count of external HTTP clients / SDK initializations.

## Migration

- `migration_layout_detected` — at least one of: parallel V1+V2 directory pair (`v1/`+`v2/`, `legacy/`+`new/`, `<name>/`+`<name>_v2/`), version-suffixed sibling modules (`*_v1.*`+`*_v2.*` paired files), workspace package with `-v2`/`-next`/`-new` suffix, README explicitly documents V1→V2 migration. Loads the `migration` pack.
- `migration_ledger_present` — `ai/migration/ledger.md` exists. Used by `port-feature` + `migration-status` to gate operations.

## REFINE mode (round-two deep extraction)

- `refine_mode` — set when `/setup-project --refine` flag is active. Gates Phases 2.7-2.12, Phase 4.6-DEEP, Phase 4.7-DEEP, Phase 5.5. Topic specs use this trigger to gate REFINE-only skills (deep extractors + anchor-density scorer).
- `refinement_eligible` — composite trigger, true when `.claude/` artifacts exist (≥1 generated agent/skill/rule/command) AND avg anchor-density score < 70 from prior `_setup-quality.md` (or no prior file). Surfaced in `--health` output as a hint to run `--refine`.
- `git_log_accessible` — `.git/` exists AND `git log` returns ≥ 1 commit (rules out shallow clones / permission failures). Required by `extract-failures-from-history`.
- `min_commits_<N>` — git log has ≥ N commits (e.g. `min_commits_30` is the floor for failure-history extraction to produce useful theme grouping).
- `business_domain_detected` — Phase 2.x business-domain detection produced ≥ 1 confirmed domain. Required by `extract-domain-entities-deeply`.
- `backend_track` — backend pack is selected (load-bearing). Used to gate `extract-hotpaths` (no backend → no hot-path uplift relevant).

## Composite / convenience

- `codebase_age_above_2y` — first commit older than 2 years (proxy for legacy concerns).

---

## How to add a new trigger

1. Add the name + one-line description here, in the right section.
2. Implement detection in `extract-codebase-overview` — usually a new line in the relevant Step (1-12). Persist the result as a key in `.claude/_extracted-codebase.md`.
3. Reference the trigger from at least one topic spec — otherwise it has no consumer.
4. Avoid synonyms — search this file before inventing a name.

## Hard rules

- **Triggers are case-sensitive snake_case.**
- **Triggers MUST evaluate deterministically** from `_extracted-codebase.md` — no LLM judgment in the gate.
- **An unrecognized trigger name = error**, not a silent skip. The pack-loader Phase 4.0 fails fast with "unknown trigger: X (not in _trigger-vocabulary.md)."
- **A new trigger needs a Step in the orchestrator that emits it.** A trigger no extractor produces is dead code.
