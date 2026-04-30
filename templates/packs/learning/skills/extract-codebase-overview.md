---
name: extract-codebase-overview
description: Master orchestrator for deep codebase analysis in /setup-project Phase 2. Walks the project's architecture, modules, base classes, data model, API surface, naming conventions, and dependency graph — outputs `.claude/_extracted-codebase.md`, the substrate every Phase 4 generator reads to author project-specific (not generic) content. Invokes sub-skills (extract-base-class-idiom, extract-business-context) and consolidates results.
---

# Skill: extract-codebase-overview

## Purpose

`/setup-project` historically detected stack (manifest scan) + signals (grep) + walked one module. That's enough to copy generic packs but NOT enough to AUTHOR project-specific content. This skill produces the **full picture** that Phase 4.2-AUTHOR reads to generate output that matches your codebase as if a senior engineer who lives here wrote it.

The output (`.claude/_extracted-codebase.md`) is the **single source of truth** for every downstream generator: pattern files, agent system prompts, rules, conventions doc, ADRs.

## Premise

- Real source is the truth. Walk manifests + source files + migrations + tests + git log before populating a single section.
- Every cited path, base class, entity, controller, signal, and convention claim resolves to a real file at the current commit.
- Every confidence assertion (e.g. "multi-tenant: confirmed") is backed by ≥2 corroborating cites per Step 15.
- Empty extraction is honest — the explicit "no ORM-like data layer detected" / "no modules detected" / `[EXTRACTION-WEAK: <reason>]` flag is a valid section outcome.
- Fabrication — inventing a base class from a folder name, a convention from one occurrence, a signal from a dep that isn't actually used — corrupts every Phase 4 generator that reads this file.

## Mechanical halt

- Hand-wave content in any section — `etc.`, `...`, `roughly layered MVC`, `appears multi-tenant`, a row without `<path>` citation, a signal claim without ≥2 corroborating files — REFUSE to write.
- Regenerate the section with concrete cites OR downgrade it to `[EXTRACTION-WEAK: <section>]` per Step 15.
- When a section genuinely has nothing (empty repo, no ORM, no controllers, no tests), record `<NOT-DETECTED: <section>: <reason>>` instead of synthesizing a placeholder row.
- Quality flags propagate to Phase 4.2-AUTHOR which falls through to COPY mode for affected topics — silent fabrication breaks that fallback.

## When to use

- `/setup-project` Phase 2 — runs once at the top of every ENHANCE / REFRESH session.
- On-demand via `/refresh-knowledge` after major refactors / new modules / dependency upgrades.
- Skipped in CREATE mode (no codebase to read yet — placeholder created, refresh runs once code exists).

## Inputs

- `project_root` — absolute cwd (the project being analyzed).
- `output_path` — defaults to `<project_root>/.claude/_extracted-codebase.md`.
- `parallelism` — default 6 concurrent extractor subagents (cap to avoid runaway tokens on huge repos).

## Procedure

### Step 1 — Stack + manifest detection (fast, deterministic)

Run Appendix A of setup-project.md detection commands. Capture:
- Languages (TypeScript, Python, Go, etc. — from file extensions).
- Frameworks (NestJS, Django, Rails, etc. — from manifests).
- Databases + ORMs (Postgres, MySQL, TypeORM, Prisma, etc.).
- Build tools (esbuild, vite, webpack, bun, turbo, etc.).
- Test frameworks (Jest, Vitest, Pytest, RSpec, etc.).
- Package manager (`bun`, `pnpm`, `npm`, `pip`, `cargo`, etc.).

**Persist as `## Stack` section.**

### Step 2 — Repository shape

Detect:
- **Single-repo** vs **monorepo** (presence of `pnpm-workspace.yaml`, `lerna.json`, `nx.json`, `turbo.json`, Cargo `[workspace]`, `go.work`, etc.).
- **Workspace** vs **mono-app** (workspaces with multiple deployable apps vs library-style packages).
- **Apps + libs split**: enumerate top-level `apps/`, `packages/`, `libs/`, `services/` dirs.

For each app/lib found, record: name + path + manifest type + brief purpose (parse from package.json description or top of root README).

**Persist as `## Repository shape` section.**

### Step 3 — Architecture + layering

For the largest app (or each app in a workspace), walk top-level source dirs and infer the architectural style:
- **Layered MVC**: `controllers/` + `services/` + `models/`.
- **Hexagonal / Clean**: `core/` + `application/` + `infrastructure/` + `adapters/`.
- **Module-per-feature**: each subdir under `src/<feature>/` has its own controller + service + repo.
- **DDD**: presence of `aggregates/`, `value-objects/`, `domain-events/`.
- **Functional / no-classes**: predominantly modules of pure functions.

Detect dependency direction via import graph (sample 5-10 files per layer; check what they import). Flag if direction violates declared style.

**Persist as `## Architecture` section.**

### Step 4 — Module enumeration

Walk `src/`, `apps/*/src/`, `libs/*/src/`. Each subdir at depth 1-2 that contains a controller + service + repo (or analogue) = one module.

For each module, record one row:
- name, path, layer (core/feature/infra/lib), purpose (one-line from README or top comment), primary entity, file count.

Cap at 80 modules in the output (sample more if larger; emit `(+N more)` line).

**Persist as `## Modules` section table.**

### Step 5 — Base class detection (then delegate)

For every TypeScript/Python/Java/etc. class with subclasses, count extenders:
```bash
# TS example
grep -rln "extends <BaseName>" --include="*.ts" .
```

Capture every base class with **≥3 extenders**. For each:
- Path of the base class file.
- Extender count.
- Sample 3-5 representative extenders (smallest, most-customized, edge-case).

For each base class meeting the threshold: **invoke `extract-base-class-idiom` skill** with `base_class_path` + `output_path = .claude/_extracted-idioms.md` (append section per base). Run up to `parallelism` extractions concurrently via Explore subagents.

If a base class has <3 extenders: skip extraction; record name + path + extender count only ("not yet load-bearing — re-evaluate on next refresh").

**Persist as `## Base classes` section + cross-link to `_extracted-idioms.md`.**

### Step 6 — Data model

Find the entity/model layer:
- TypeORM: `*.entity.ts` files.
- Prisma: `schema.prisma`.
- SQLAlchemy: `Base.metadata` consumers.
- Django: `models.py`.
- ActiveRecord: `app/models/*.rb`.
- Sequelize: `*.model.ts`.

For each entity, record: name, path, table name (if explicit), columns (just names + types — not values), relations (`@OneToMany`, `belongs_to`, etc.), softdelete? (look for `deleted_at` column or `@SoftDelete()` decorator), tenantId? (look for `tenantId` / `tenant_id` column).

Cap at 60 entities; emit `(+N more)` line.

Detect cross-cutting concerns visible at the data layer:
- All entities have `tenant_id` → **multi-tenant** signal confirmed.
- All entities extend `SoftDeleteEntity` / `BaseEntity` → soft-delete is universal.
- Translation tables (`*_translations`) exist → i18n at data layer.
- Audit columns (`created_by_id`, `updated_by_id`) → audit subscriber pattern.

**Persist as `## Data model` section.**

### Step 7 — API surface

Find controllers / routers / route files:
- NestJS: `*.controller.ts` with `@Controller()`.
- Django: `urls.py` + view classes.
- FastAPI: files with `@app.get` / `@router.get`.
- Express: `app.use(...)` / `router.get(...)`.
- Rails: `routes.rb` + `*_controller.rb`.

For each controller, record: name, path, route prefix, # endpoints, auth scheme used (decorator/middleware).

Also detect: how does the project structure response shapes? (e.g., `createApiResponse(dto, message)` wrapper detected → standard response envelope is in use). What's the error mapper? (HTTP exception filter, problem-details middleware, etc.).

**Persist as `## API surface` section.**

### Step 8 — Convention auto-detection

Sample 10 files per category and extract patterns:
- **File naming**: kebab-case / snake_case / camelCase / PascalCase. Suffix patterns (`.service.ts`, `.controller.ts`, `_service.py`, etc.).
- **Class naming**: PascalCase confirmed. Suffix matrix (Service / Controller / Repository / Mapper / Entity).
- **Property naming**: camelCase / snake_case.
- **DB column naming**: from migrations or entity column decorators.
- **Test naming + colocation**: `*.spec.ts` / `test_*.py`. Colocated next to source vs separate `test/` dir.
- **Constants**: UPPER_SNAKE_CASE / PascalCase / etc.
- **Imports**: relative-only / alias-based (`@app/`, `@/`, `~/`). Read tsconfig/pyproject for aliases.
- **DI tokens**: string constants / Symbols / class refs.

**Persist as `## Conventions` section** with a complete suffix matrix table.

### Step 9 — Cross-cutting concerns + signals

Re-run signal detection from Appendix A but with deeper grep + corroboration:
- multi-tenant: tenant_id columns + AsyncLocalStorage usage + tenant resolution middleware.
- payment: SDK in deps + actual integration code.
- AI: SDK in deps + prompt construction code.
- multi-currency: currency columns + conversion service.
- search: Elastic/Meili/Typesense + indexing code.
- background-jobs: queue lib + worker definitions.
- (full list per Appendix A)

For each detected signal, note: confidence (number of corroborating signals), entry-point files, anti-patterns observed (e.g., manual tenant filter outside the auto-applied path).

**Persist as `## Cross-cutting concerns` section.**

### Step 10 — Tests + coverage shape

- Test file count.
- Test framework + colocation pattern.
- Existence of e2e tests + their location.
- Mock strategy (jest.fn, sinon, pytest fixtures, factories).
- CI config: which tests run on PR? (parse `.github/workflows/*` if present).

**Persist as `## Tests` section.**

### Step 11 — Anti-patterns observed (acknowledge, don't fix)

Count + sample paths:
- `console.log` / `print(` outside loggers.
- `any` / `Any` type usage.
- Empty catch blocks (`catch {}`, `except: pass`).
- TODO / FIXME / XXX / HACK comments.
- `// @ts-ignore` / `# type: ignore`.
- Commits with messages like "wip", "fix later", "revert".

**Persist as `## Anti-patterns observed` section.** This is intel for generated rules to know what to NOT introduce — not a fix list.

### Step 12 — Recent activity (last 30 days)

```bash
git log --since="30 days ago" --pretty=format:"%h %s" | head -50
git log --since="30 days ago" --diff-filter=A --name-only | sort -u | head -50  # new files
```

Summarize: which areas saw the most activity? Any large refactors? Any new modules added? This gives the brain a "what's in flight" hint.

**Persist as `## Recent activity` section.**

### Step 13 — Delegate to extract-business-context

Invoke the `extract-business-context` skill with `output_path = .claude/_extracted-business.md`. That skill captures mission / personas / KPIs / business model / anti-goals from README + git log + project name + manifest description, asking the user only for genuinely missing facets.

Cross-link in the codebase overview: `## Business context: see _extracted-business.md`.

### Step 14 — Write the output

Write `.claude/_extracted-codebase.md` with all 12 sections above (skipping Step 13 which writes its own file). Top of file:

```markdown
# Codebase Extracted Overview
Generated: <ISO timestamp> by `/setup-project` Phase 2
Source: `extract-codebase-overview` skill
Consumed by: Phase 4.2-AUTHOR generators (every output that mentions paths / base classes / conventions reads this)

> ⚠ THIS FILE IS REGENERATED — never hand-edit. Hand-edits in companion files:
> - `ai/conventions.md` (the human-readable summary of `## Conventions` here)
> - `ai/business-domain.md` (the human-readable summary of `_extracted-business.md`)
```

### Step 15 — Quality verification

Before returning success:
- Every cited file path exists (no hallucinations from grep misreads).
- `## Modules` section has ≥1 row OR an explicit "no modules detected — empty/script project" note.
- `## Base classes` section accounts for every `extends X` with ≥3 hits found in Step 5.
- `## Data model` section has ≥1 entity OR an explicit "no ORM-like data layer detected" note.
- Every confidence claim (e.g., "multi-tenant: confirmed") cites ≥2 corroborating files.

If any check fails: regenerate the offending section (one retry). If still failing: write the section with `[EXTRACTION-WEAK: <reason>]` flag — Phase 4.2-AUTHOR will fall back to COPY mode for affected topics.

## Output format

Single file: `.claude/_extracted-codebase.md`. Markdown with H2 sections in the order above. Every code path cited as `<relative-path>:<line>` for verifiability.

Print to stdout:
```
Extracted codebase overview → .claude/_extracted-codebase.md
  Stack: <key items>
  Modules: <N>
  Base classes (≥3 ext): <N>  → .claude/_extracted-idioms.md (M sections)
  Entities: <N>
  Controllers: <N>
  Conventions: <suffix matrix items>
  Signals confirmed: <list>
  Anti-patterns flagged: <count by type>
  Business context: → .claude/_extracted-business.md
  Quality flags: <none | list of [EXTRACTION-WEAK]>
```

## Failure modes

- **Empty project (no source files)** → write skeleton overview with `## Stack` only + note "extraction deferred until code exists." Phase 4 falls through to CREATE-mode behavior.
- **Massive monorepo (>10k source files)** → cap walk depth to 4; sample by file count, not exhaustive walk. Note `[SAMPLED]` in any sections that didn't visit every file.
- **Repo without git** → skip Step 12 (recent activity). All other steps work.
- **Unrecognized stack** → still emit `## Stack` with raw findings ("manifests detected: X, Y") + ask user one consolidated question to confirm framework.
- **Extraction conflicts with prior `_extracted-codebase.md` (REFRESH)** → write the new one; emit `## Diff vs prior` section listing what changed (added/removed/changed). Phase 6 learning loop reads this diff.

## Quality bar

The output should let any downstream generator (pattern author, agent author, rule author) write project-specific content **without asking another question + without re-grepping the codebase**. If the generator still needs to look something up, this skill missed it.
