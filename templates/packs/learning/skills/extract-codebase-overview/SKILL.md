---
name: extract-codebase-overview
description: Master orchestrator for deep codebase analysis in /setup-project Phase 2. Walks the project's architecture, modules, base classes, data model, API surface, naming conventions, and dependency graph — outputs `.claude/_extracted-codebase.md`, the substrate every Phase 4 generator reads to author project-specific (not generic) content. Invokes sub-skills (extract-base-class-idiom, extract-business-context) and consolidates results.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# Skill: extract-codebase-overview

## Purpose

`/setup-project` historically detected stack (manifest scan) + signals (grep) + walked one module. That's enough to copy generic packs but NOT enough to AUTHOR project-specific content. This skill produces the **full picture** that Phase 4.2-AUTHOR reads to generate output that matches your codebase as if a senior engineer who lives here wrote it.

The output (`.claude/_extracted-codebase.md`) is the **single source of truth** for every downstream generator: pattern files, agent system prompts, rules, conventions doc, ADRs.

## Premise

- Real source is the truth. Walk manifests + source files + migrations + tests + git log before populating a single section.
- Every cited path, base class, entity, controller, signal, and convention claim resolves to a real file at the current commit.
- Every confidence assertion (e.g. "multi-tenant: confirmed") is backed by ≥2 corroborating cites per Step 15.
- **Every claim declares its provenance class** (per `phase-2-profile.md § Provenance discipline`): a resolving `<path:line>` citation = found; no citation → the claim MUST carry `[inferred: <basis>]` or `[unconfirmed]`. Inference stated as fact is the Trusted Summary anti-pattern applied to the oracle itself.
- Empty extraction is honest — the explicit "no ORM-like data layer detected" / "no modules detected" / `[EXTRACTION-WEAK: <reason>]` flag is a valid section outcome.
- **Partial extraction is honest too — but only when it says so.** Several steps below cap or sample *by design* (Steps 3, 4, 5, 6, 8, 12). A section built from a sample carries `[SAMPLED: <seen>/<present> <unit>]` on its heading, and every run reports `## Coverage` unconditionally — including at 100%, which is the strongest claim this skill can make about its own output. A citation proves the file it points at; it never proves the population that file was drawn from.
- Fabrication — inventing a base class from a folder name, a convention from one occurrence, a signal from a dep that isn't actually used — corrupts every Phase 4 generator that reads this file.

## Mechanical halt

- Hand-wave content in any section — `etc.`, `...`, `roughly layered MVC`, `appears multi-tenant`, a row without `<path>` citation, a signal claim without ≥2 corroborating files — REFUSE to write.
- An uncited claim with no `[inferred: <basis>]` / `[unconfirmed]` marker is the same violation — regenerate with a citation or downgrade the claim to its honest provenance class (per `phase-2-profile.md § Provenance discipline`).
- A **generalizing** claim ("all entities carry a tenant column", "file naming is always kebab-case", "errors always route through the shared handler") drawn from a `[SAMPLED]` section may NOT be written as `[found:]`. The citation resolves; the generalization does not. Downgrade to `[inferred: <basis>; sampled <seen>/<present> <unit>]` per `phase-2-profile.md § Provenance discipline`. This is the one provenance error a resolving citation actively hides — Step 15's path check passes it, which is exactly why check 7 exists.
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
- `parallelism` — default 6 concurrent extractor subagents (cap to avoid runaway tokens on huge repos). Recorded in `## Coverage` as part of `walk_scope`: it bounds what the run *could* visit, so it belongs with the census, not in a comment.
- `repo_shape` — **required**, one of `single` / `monorepo` / `workspace`. Decided by Phase 1 (`phase-1-detect-mode.md § Decide shape`) and handed in verbatim per `phase-2-profile.md § 2.0.a`. Step 2 consumes it; it is never re-derived here.
- `shape_signal` — **required**, the Phase 1 table row that fired, as a string. Recorded verbatim in `## Repository shape` so a reader can audit the shape decision without re-running it.
- `members` — **required**, never empty; `single` carries exactly one entry, root `.`. One entry per member:
  ```
  members:
    - name: <member-a>
      root: <path/to/member-a>    # `.` for repo_shape: single
      manifest: <path/to/member-a/<manifest-file>>   # or `(none)`
  ```
  This list is the split key for Step 2, Step 2.5 and every capped step. **Absent or empty `members` is a halt, not a default** — see Step 2.

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

### Step 2 — Repository shape (handed in, not re-derived)

`repo_shape`, `shape_signal` and `members` arrive as inputs. This step **consumes** that decision; it does not re-answer it.

**Do not scan for a workspace manifest to decide the shape here.** `pnpm-workspace.yaml`, `lerna.json`, `nx.json`, `turbo.json`, Cargo `[workspace]`, `go.work` cover only the two shapes that declare their own members. The two that declare nothing — sub-manifest dirs inside ONE git repo (**monorepo**), and separate checkouts or a plain `server/`-beside-`client/` pair under one parent (**workspace**) — are precisely the shapes a manifest scan answers `single` for, and a plain `server/` + `client/` pair matches none of `apps/` / `packages/` / `libs/` / `services/` either. That silent `single` is not a loud failure: it writes zero member entries, Step 2.5 collapses to one `(root/other)` bucket, and every per-member contract below becomes unreachable without anything refusing. Phase 1 already fired on signals a manifest scan does not reproduce; re-deriving here discards that answer.

**Missing input is a halt, not a default.** `members` absent or empty → do NOT proceed to Step 2.5, and do NOT enumerate members yourself. Write `[SHAPE-INPUT-MISSING: members not handed in by Phase 1]` and stop; re-invoke with the Phase 1 output (`phase-2-profile.md § 2.0.a`). Inventing the list here reintroduces the exact bug the input exists to remove.

**The entry set IS `members`** — same order, one `## Repository shape` entry each, no additions and no drops. Per entry record:

| Field | Source | Rule |
|---|---|---|
| `name`, `root` | the input, verbatim | Never rewritten, never normalized away. |
| `manifest` | the input, verbatim | `(none)` is a legal value. A member directory with no manifest is still a member — that is the sibling-directory shape, not a non-member. |
| manifest type, one-line purpose | the member's OWN manifest description, or the top of the member's README | **Enrichment only.** `[unconfirmed]` when neither exists. Enrichment never adds, removes, renames or merges a member. |

Record `repo_shape` and `shape_signal` verbatim at the top of the section, so the shape decision is auditable from the artifact without re-running detection.

`repo_shape: single` carries exactly one member, root `.` — the same code path, not a special case.

**Halt**: `members` holds ≥ 2 entries while the section you are about to write holds 1. That is a dropped member; a member with no entry gets no census bucket, so it gets no walk, no conventions row, and no rules. Fix the entry set before continuing — `phase-5-verify.md § 5.1` errors on exactly this state, and nothing downstream can recover a split the substrate never made.

**Persist as `## Repository shape` section.**

### Step 2.5 — Source census (deterministic — runs before any prose is written)

Six of the steps below cap or sample. Until the population they sampled *from* is written down, "sample 10 files per category" is not a disclosure — it is a number with no denominator. This step computes the denominator, in shell, before the model writes a word of prose. That ordering is the whole point: Step 15 check 7 is then arithmetic against numbers the model did not author.

**Denominator (`present`) — tracked files, not `find`:**

```bash
git ls-files -z | tr '\0' '\n'        # census_method: git-ls-files
git rev-parse --short HEAD             # the commit the census is pinned to
```

`git ls-files` for three reasons: it inherits `.gitignore` for free, so vendored / installed / built trees never enter the denominator; it is deterministic at a commit, which is the same premise every citation in this file rests on (§ Premise); and it is uniform across every stack. **Repo without git** (already a declared failure mode) → fall back to `find` with an explicit exclude list and record `census_method: find`, so the number is only ever compared against another `find` number.

From that list, keep files whose extension is in the source-extension set derived from `## Stack` (Step 1), then subtract — and **name every subtraction in the output**:

- test-glob matches (Step 10 owns those; they are counted separately, not silently dropped),
- lockfiles and manifests,
- generated / vendored paths not already excluded by `.gitignore`,
- non-source extensions (docs, fixtures, assets, data).

An exclusion that is not named in the output makes the denominator unfalsifiable — the same violation § Premise forbids of every other claim in this file. If "is a `.sql` migration a source file?" is a judgement call, the answer does not matter as long as the call is printed.

Bucket the survivors **one row per `## Repository shape` entry** (Step 2) — which is one row per handed-in `member`, since Step 2's entry set IS `members` — plus a `(root/other)` row for tracked files under no member root. Without the per-package split, one well-covered app hides nine untouched ones behind a healthy aggregate. **Halt**: fewer buckets than `members` means a member was dropped upstream; return to Step 2 rather than writing an aggregate census that cannot show the gap.

**Numerator (`seen`) is NOT computed here.** It is counted in Step 15 as `files_cited` — the distinct paths appearing in `[found:]` citations actually written. Never label it `files_read`. It undercounts (a file can be read and cite nothing) and that is the correct trade: `files_cited` is the only number a third party can audit from the artifact alone, and Step 15 already walks every citation to confirm the path resolves. An unauditable coverage number would be a worse failure than today's silence.

Also record, for the header block: `census_method`, `walk_scope` (which directories the walk was allowed to enter, the depth cap in force, and `parallelism`), and the per-package `present`.

**Per-section denominators.** Each capped step declares what its population is, so its `[SAMPLED: <seen>/<present> <unit>]` marker is an auditable ratio rather than an adjective:

| Section | Population (`present`) | `seen` | Cap forcing the sample |
|---|---|---|---|
| `## Architecture` (Step 3) | source files under the layer dirs walked | files cited | 5-10 sampled per layer |
| `## Modules` (Step 4) | dirs matching the module test | rows emitted | cap 80 |
| `## Base classes` (Step 5) | bases with ≥3 extenders | bases with an idiom extraction | `parallelism` |
| `## Data model` (Step 6) | entity files matched by the Step-6 globs | rows emitted | cap 60 |
| `## API surface` (Step 7) | controller / router files found | rows emitted | **none declared → must be 100%** |
| `## Conventions` (Step 8) | files per category | files sampled per category (10) | sample 10 per category — **plus** `[CONTESTED: <A> n/N, <B> m/N]` per non-unanimous category (Step 8) |
| `## Cross-cutting concerns` (Step 9) | files matched by that signal's detection greps | files cited as corroboration | none declared — **a signal verdict is a ratio, never a bare word** (Step 9) |
| `## Anti-patterns observed` (Step 11) | source files in the member's bucket (the same `present` the census computed) | files the grep actually matched | none declared — a count with no population is not a finding (Step 11) |
| `## Recent activity` (Step 12) | commits in the window | 50 | `head -50` |

A `[CONTESTED]` row is auditable off this table for the same reason a `[SAMPLED]` heading is: both denominators are printed. `n + m ≤ sampled` and `sampled ≤ present` are checkable arithmetic, so a contest cannot be asserted without a population to assert it over.

**Every population in that table is per member.** When `members` holds ≥ 2 entries, each capped or sampled step below runs once per member, over that member's own bucket, and every row it emits names the member it came from. A step that walks the union and reports one winner produces a blended value that is wrong for every member and carries a citation that resolves — which is what lets it survive review (`phase-2-profile.md § 2.0.a` obligation 3, `§ 17`). Cross-member aggregates may be reported *in addition*, never *instead*.

**Persist as `## Coverage` section** — written last (it needs Step 15's numerator) but placed **FIRST** in the body, before `## Stack`. First, not last: a reader who reaches `## Conventions` should already know what it rests on.

### Step 3 — Architecture + layering

For **each member** in `## Repository shape` (Step 2), walk that member's top-level source dirs under its `root` and infer the architectural style — one verdict per member, never one blended verdict over the union:
- **Layered MVC**: `controllers/` + `services/` + `models/`.
- **Hexagonal / Clean**: `core/` + `application/` + `infrastructure/` + `adapters/`.
- **Module-per-feature**: each subdir under `src/<feature>/` has its own controller + service + repo.
- **DDD**: presence of `aggregates/`, `value-objects/`, `domain-events/`.
- **Functional / no-classes**: predominantly modules of pure functions.

Detect dependency direction via import graph (sample 5-10 files per layer; check what they import). Flag if direction violates declared style.

**Persist as `## Architecture` section** — heading carries the Step 2.5 `[SAMPLED: <seen>/<present> files]` marker whenever the per-layer sample did not exhaust the layer dirs walked.

### Step 4 — Module enumeration

Walk **each member's own source dir** — `<member.root>/src/`, `<member.root>/app/`, or whatever that member actually uses. Do NOT walk a fixed `apps/*/src/` / `libs/*/src/` glob as the member source: it misses every sibling-directory member (a plain `server/` + `client/` pair matches neither), which is the same manifest-shaped blindness Step 2 removes. Each subdir at depth 1-2 that contains a controller + service + repo (or analogue) = one module.

For each module, record one row:
- **member**, name, path, layer (core/feature/infra/lib), purpose (one-line from README or top comment), primary entity, file count.

Cap at 80 modules in the output (sample more if larger; emit `(+N more)` line).

**Persist as `## Modules` section table** — when the 80-cap fires, the `(+N more)` line stays AND the heading carries `[SAMPLED: <rows>/<dirs matching the module test> modules]`. The `(+N more)` line discloses the truncation; the marker is what downstream consumers parse.

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

**Persist as `## Base classes` section + cross-link to `_extracted-idioms.md`** — heading carries `[SAMPLED: <bases with an idiom extraction>/<bases with ≥3 extenders> bases]` when `parallelism` or a run-length cap left qualifying bases unextracted.

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

**Persist as `## Data model` section** — when the 60-cap fires, keep `(+N more)` AND add `[SAMPLED: <rows>/<entity files matched> entities]` to the heading. The cross-cutting inferences directly above ("ALL entities have a tenant column") are exactly the generalizing claims § Mechanical halt forbids writing as `[found:]` off a sample.

### Step 7 — API surface

Find controllers / routers / route files:
- NestJS: `*.controller.ts` with `@Controller()`.
- Django: `urls.py` + view classes.
- FastAPI: files with `@app.get` / `@router.get`.
- Express: `app.use(...)` / `router.get(...)`.
- Rails: `routes.rb` + `*_controller.rb`.

For each controller, record: name, path, route prefix, # endpoints, auth scheme used (decorator/middleware).

Also detect: how does the project structure response shapes? (e.g., `createApiResponse(dto, message)` wrapper detected → standard response envelope is in use). What's the error mapper? (HTTP exception filter, problem-details middleware, etc.).

**Persist as `## API surface` section** — no cap is declared for this step, so the Step 2.5 denominator row requires `seen == present` here, and **check 7 now enforces it** (see its `none declared → must be 100%` bullet). Until that bullet existed, a short walk marked `[SAMPLED: <seen>/<present> files]` passed check 7 while breaching this step's floor: the check only rejected an *undisclosed* sample, and a disclosed one looked identical to a complete walk. Disclosure is still required; it is no longer sufficient. If a run cannot reach every controller / router file found, that is a real coverage loss and the heading must say so rather than the cap being invented after the fact.

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

**Per category, the sample is not always unanimous — record the split, never the winner.** `[SAMPLED: 10/412 files]` is emitted identically whether 10 of 10 sampled files agreed or 6 of 10 did. Disagreement *inside* the sample is a different fact from disagreement between the sample and the population, and until this step records it, nothing downstream can: the honest output of a legacy codebase with three competing conventions was an average true of none of them, stated as this project's convention, carried into `ai/conventions.md` and into the anchor at the top of every adapted rule, where the next agent uses it to "fix" the code that follows the other two.

When a category's sample is **not unanimous**, the row carries:

```
[CONTESTED: <option-A> <n>/<sampled>, <option-B> <m>/<sampled>]
```

and the claim is written `[inferred: <basis>; contested <n>/<m>; sampled <sampled>/<N> files]` — never `[found:]`, and never as "the project's convention". Both options get a `<path:line>`. Report the split with its counts; do NOT pick a winner, do NOT round a 6/4 to "mostly A", and do NOT drop the minority as noise. If one option is clearly the newer one (concentrated in recently-touched files per Step 12) say so as an observation with its evidence, and still record both.

This is the same shape two later profile fields already use — `[CONCURRENCY-DRIFT: <primitive-A> at <n> sites, <primitive-B> at <m> sites]` and `[MIGRATION-WEAK]` (`phase-2-profile.md § Profile content` fields 15-16). Those two were written as one-off exceptions for two topics that happened to be noticed; `[CONTESTED]` is that shape generalized to the section where it does the most damage. A category that IS unanimous across its sample carries no `[CONTESTED]` marker — the marker's absence has to mean "checked and agreed", which is why it is emitted per category rather than per file, and why a category whose disagreement was never checked may not go unmarked.

**Persist as `## Conventions` section** with a complete suffix matrix table — heading carries `[SAMPLED: 10/<files in category> files]` per category sampled, and each contested row carries its own `[CONTESTED: …]` marker inline. A section can be both: `[SAMPLED]` reports how much was read, `[CONTESTED]` reports what was found in it. They answer different questions and neither substitutes for the other.

This is the highest-blast-radius section in the file: it drives `ai/conventions.md`, the `## Project-specific` block at the top of *every* adapted rule, and the suffix matrix. Generalized from 10 files, every row still earns a resolving citation, so the provenance sweep passes it — a convention observed in 10 of 400 files becomes law with proof attached. That is precisely the failure § Mechanical halt's generalizing-claim rule and Step 15 check 7 exist to catch: each row that generalizes beyond the sample is written `[inferred: <basis>; sampled 10/<N> files]`, not `[found:]`.

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

**The verdict is a ratio, and only three words are legal.** This section is the most confidently-worded
in the file and it was, until this row existed, the least constrained: `multi-tenant: **confirmed**`
could be written off two corroborating files out of four hundred, and no denominator anywhere
contradicted it. Write instead:

```
<signal>: <confirmed|partial|not-detected> [<matched>/<present> files; entry: <path:line>, <path:line>]
```

- **`confirmed`** — the signal's greps match, AND the pattern holds **repo-wide** for the property
  claimed. For a *pervasive* property (multi-tenancy, i18n, auth) that means `matched / present`
  covers the population the property is asserted over — a `tenant_id` column on 6 of 412 entity
  files is `partial`, not `confirmed`, however many corroborating files you cite. For a *presence*
  property (payment SDK integrated, search engine wired) two corroborating files genuinely are
  enough, because the claim is "this exists here", not "this holds everywhere".
- **`partial`** — the signal is real and does not cover its population. Name what it covers:
  `multi-tenant: partial [6/412 entity files carry tenant_id; scoped to billing/, orders/]`. This
  is the most useful verdict this step produces and the one a bare `confirmed` destroys.
- **`not-detected`** — greps ran, nothing matched. Say which greps, per § Mechanical halt.

> **Hard rule:** `confirmed` on a pervasive property without `<matched>/<present>` printed beside it
> is the same violation as an uncited factual claim, and Step 15 check 7 fails it. "Cites ≥2
> corroborating files" is a floor on evidence, never a licence to generalise from it — that
> inference is exactly what § Mechanical halt's generalizing-claim rule and Step 6's own note
> ("the cross-cutting inferences directly above … are exactly the generalizing claims § Mechanical
> halt forbids") already forbid one section earlier. This step restates it because it is the step
> that emits the strongest word in the file.

**Persist as `## Cross-cutting concerns` section**, with `[SAMPLED: <seen>/<present> files]` on the
heading whenever the corroboration walk did not cover the population — same rule as every other
section, now that the row exists in the Step 2.5 table. Marking the heading `[SAMPLED]` does NOT
put this section's verdict lines in breach of check 7's forbidden-quantifier bullet: that bullet
carves out a Step 9 verdict that prints its own `<matched>/<present>` ratio, precisely so this
section can obey both rules at once. Write the marker; do not omit it to dodge the word list.

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

Each line is `<pattern>: <matched>/<present> files [<path:line>, <path:line>, …]` — the count is
meaningless without the population it was counted over. "47 `console.log` calls" reads as an
emergency in a 60-file project and as background noise in a 4,000-file one, and a generated rule
that mistakes the second for the first bans a practice the team has already contained.

**Persist as `## Anti-patterns observed` section**, `[SAMPLED]`-marked when the grep did not reach
every file in the bucket. This is intel for generated rules to know what to NOT introduce — not a
fix list.

### Step 12 — Recent activity (last 30 days)

```bash
git log --since="30 days ago" --pretty=format:"%h %s" | head -50
git log --since="30 days ago" --diff-filter=A --name-only | sort -u | head -50  # new files
```

Summarize: which areas saw the most activity? Any large refactors? Any new modules added? This gives the brain a "what's in flight" hint.

**Persist as `## Recent activity` section** — the `head -50` truncation is a cap like any other: heading carries `[SAMPLED: 50/<commits in the 30-day window> commits]` when the window held more than 50.

### Step 13 — Delegate to extract-business-context

Invoke the `extract-business-context` skill with:
- `output_path = .claude/_extracted-business.md`
- `extracted_codebase_path = .claude/_extracted-codebase.md` — **mandatory**, and the reason this step sits at 13 rather than at 1.

Steps 6-9 above have already extracted the evidence that answers half the business facets: entity clusters and `tenant_id` columns (Step 6), per-controller auth schemes and role/permission tables (Steps 6-7), corroborated payment / AI / search / background-jobs signals with their entry-point files (Step 9), plus contributor and cadence data (Step 12). Handing over only `output_path` meant that evidence was read and then thrown away before the question was composed — the business skill would fall back to README + manifests + git metadata and put five of eight facets to the user, several of which the walk just completed had already answered. Pass the path; the sub-skill's Step 0.5 mines it before it reads a single document.

Write the section ordering constraint down where it can be violated: `_extracted-codebase.md` need not be flushed to disk before this call, but Steps 1-12's content MUST be complete, because the sub-skill reads it. If a run reorders Step 13 earlier, it silently reverts to document-only business extraction and nothing in the pipeline notices.

Cross-link in the codebase overview: `## Business context: see _extracted-business.md`.

### Step 14 — Write the output

Write `.claude/_extracted-codebase.md` with all **13** sections above (skipping Step 13, which writes its own file): the 12 Step sections plus `## Coverage` from Step 2.5. `## Coverage` is written LAST — it needs Step 15's numerator — but placed FIRST in the body, before `## Stack`. Top of file:

```markdown
# Codebase Extracted Overview
Generated: <ISO timestamp> by `/setup-project` Phase 2
Source: `extract-codebase-overview` skill
Consumed by: Phase 4.2-AUTHOR generators (every output that mentions paths / base classes / conventions reads this)
approved_by:          <!-- empty at generation — human reviewer stamps <name>@<iso> after reading; see phase-2-profile.md § Oracle approval -->
approved_hash:        <!-- body hash at approval — /setup-project-health check 9 prints the paste-ready stamp command -->
Provenance: every claim is [found: <path:line>] (citation = marker), [inferred: <basis>], or [unconfirmed] — per phase-2-profile.md § Provenance discipline
Coverage: <S>/<P> source files cited (<PP>%) — census <git-ls-files|find>@<short-sha>; per-package + per-section seen/present in ## Coverage

> ⚠ THIS FILE IS REGENERATED — never hand-edit. Hand-edits in companion files:
> - `ai/conventions.md` (the human-readable summary of `## Conventions` here)
> - `ai/business-domain.md` (the human-readable summary of `_extracted-business.md`)
```

`Coverage:` sits beside `Provenance:` deliberately — they are the same kind of fact, and both sit next to the `approved_by:` stamp, because coverage is part of what a reviewer is being asked to approve. It is a plain `Coverage:` key, **not** an `approved_`-prefixed one: the approval recipe is `grep -v '^approved_' … | shasum`, so `## Coverage` and this line are *inside* the hashed body. Coverage changing therefore invalidates the approval stamp and forces a re-read. That is correct and costs nothing.

### Step 15 — Quality verification

Before returning success:
- Every cited file path exists (no hallucinations from grep misreads).
- `## Modules` section has ≥1 row OR an explicit "no modules detected — empty/script project" note.
- `## Base classes` section accounts for every `extends X` with ≥3 hits found in Step 5.
- `## Data model` section has ≥1 entity OR an explicit "no ORM-like data layer detected" note.
- Every confidence claim in `## Cross-cutting concerns` follows Step 9's three-word grammar and prints `<matched>/<present>`. Two corroborating files is the floor for `confirmed` on a *presence* property and is never sufficient for a *pervasive* one — check 7 below is what enforces the difference.
- **Provenance sweep**: no factual claim is both uncited AND unmarked — each is `[found:]` (via citation), `[inferred: <basis>]`, or `[unconfirmed]`. Count per class; the counts go to stdout and feed `/setup-project-health` check 9.
- **Coverage sweep (check 7)**: count `files_cited` = the distinct paths appearing in `[found:]` citations (the walk of every citation is already happening for check 1 — this is a `sort -u | wc -l` over it, not a second pass). Then, for every row of the Step 2.5 per-section table:
  - `seen` and `present` are both integers present in `## Coverage` — a missing or non-numeric denominator fails, it does not default to "assume complete";
  - `seen < present` and the heading carries **no** `[SAMPLED: <seen>/<present> <unit>]` → **FAIL** (undisclosed sample);
  - `seen == present` and the heading **does** carry `[SAMPLED]` → **FAIL** (a false `SAMPLED` makes every downstream consumer degrade for nothing, which is how a coverage signal gets switched off);
  - the row's `Cap` cell reads **`none declared`** and `seen < present` → **FAIL**, disclosed or not. A section with no declared cap has no licence to sample; `[SAMPLED: 12/40 files]` on `## API surface` is an honest report of a floor being breached, and honesty about a breach is not compliance. Remedy: finish the walk, or declare a cap in the Step 2.5 table so the sample is a decision rather than an accident;
  - every generalizing claim inside a `[SAMPLED]` section is marked `[inferred: <basis>; sampled <seen>/<present> <unit>]`, not `[found:]` (§ Mechanical halt). **This bullet is the one that was not arithmetic, so give it a closed trigger list rather than a judgement call**: inside a `[SAMPLED]` section, a line carrying `[found:]` may not also carry any of `all `, `every `, `always`, `never`, `throughout`, `repo-wide`, `project-wide`, `consistently`, `the codebase `, `confirmed` — those quantify beyond the sample by construction. A line that needs one of those words is `[inferred:]`. Greppable, so it fails the same way for everyone.

    **ONE carve-out, and it is not a loophole: a Step 9 verdict line that prints its own
    `<matched>/<present>` ratio.** Without it these three instructions are mutually
    unsatisfiable and the skill fails by construction: Step 9's grammar REQUIRES the word
    `confirmed` as one of its three verdicts, the Step 2.5 table REQUIRES `[SAMPLED]` on
    `## Cross-cutting concerns` whenever the corroboration walk did not cover the population,
    and this bullet FORBIDS `confirmed` in a `[found:]` line inside a `[SAMPLED]` section.
    Obey all three and check 7 is red no matter what you write. Measured on a live run: 11
    hits, every one of them a Step-9-mandated `**confirmed (presence)**` verdict, and they
    passed only because the author left the heading unmarked — i.e. the only way through was
    to break a DIFFERENT rule, silently. The carve-out is principled rather than convenient:
    the forbidden words are banned because they generalize BEYOND the sample, and a verdict
    that prints `<matched>/<present>` beside itself has declared its own scope — the ratio IS
    the scope. So: `confirmed` is permitted in a `[found:]` line inside a `[SAMPLED]` section
    **if and only if** the same line prints `<matched>/<present>`, and the next bullet then
    independently enforces `matched == present` for it. No ratio, no exemption. The other nine
    words have no carve-out, because none of them carries a denominator;
  - every `<signal>: confirmed` line in `## Cross-cutting concerns` that asserts a **pervasive** property carries `<matched>/<present>` and `matched == present` (Step 9). `confirmed` with a printed ratio below 100% is a `partial` mislabelled, and it is the single highest-authority claim the file makes;
  - every `[CONTESTED: <A> n/N, <B> m/N]` row has `n + m ≤ N`, `N ≤ sampled`, and a `<path:line>` for BOTH options — a contest with one citation is a preference with a footnote.

  Check 7 is different in kind from checks 1-6 and that difference is the reason it is worth adding. Its numerator and denominator were produced by shell in Step 2.5, *before* prose existed; the check is arithmetic against numbers the model did not author. Checks 2-5 can be satisfied by writing more confident prose. This one cannot.

If any check fails: regenerate the offending section (one retry). If still failing: write the section with `[EXTRACTION-WEAK: <reason>]` flag — Phase 4.2-AUTHOR will fall back to COPY mode for affected topics.

**Check 7's failure path is NOT the `[EXTRACTION-WEAK]` path.** Checks 1-6 fail because a section has no trustworthy content, so degrading it to `[EXTRACTION-WEAK]` (→ COPY mode) is the right remedy. Check 7 fails because a section has content whose *coverage is undeclared* — the remedy is to declare it. On failure: recompute the ratio, write the missing `[SAMPLED: <seen>/<present> <unit>]` marker (or remove a false one), and re-run the sweep once. Only if the census itself is unobtainable — no `git ls-files`, no usable `find` — does `## Coverage` become `[EXTRACTION-WEAK: coverage census unavailable]`, and even then the other twelve sections keep their content.

Routing a merely-sampled section to COPY mode would collapse `SAMPLED` and `EXTRACTION-WEAK` into one behaviour, at which point one of the two markers is redundant and should be deleted rather than kept. They stay distinct: **no signal → different generator; partial signal → same generator, qualified claims.**

**A coverage failure NEVER halts the run.** Same degrade-never-stop discipline as the rest of this file: a large repo that produces no oracle at all would push every track to COPY mode, which is strictly worse than an oracle that honestly reports it read 8% of the source. Check 7 flags; it does not stop.

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
  Provenance: <N> found / <N> inferred / <N> unconfirmed
  Coverage:   <S>/<P> source files cited (<PP>%)  [census: <git-ls-files|find>@<short-sha>; <X> excluded: <named reasons>]
    <pkg-a>   <s>/<p> (<pp>%)
    <pkg-b>   <s>/<p> (<pp>%)  [SAMPLED: walk depth 4]
  Sampled sections: <none | Conventions 10/412 files, Architecture 8/1204 files>
  Quality flags: <none | list of [EXTRACTION-WEAK]>
```

`Quality flags:` stays weakness-only. `Coverage:` is a fact, not a flag, and is printed on every run including at 100% — an oracle that reports only its weaknesses and never its strengths under-sells correct work, and `Coverage: 412/412 (100%)` is the strongest thing this skill can say. Note that stdout is ephemeral: the same numbers are persisted in the header block and `## Coverage`, because the reader who most needs them is the one opening `_extracted-codebase.md` cold, months later, deciding whether to stamp it.

## Failure modes

- **Empty project (no source files)** → write skeleton overview with `## Stack` only + note "extraction deferred until code exists." Phase 4 falls through to CREATE-mode behavior.
- **Massive monorepo (>10k source files)** → do NOT truncate by walk depth. Rank the census with `~/.claude/scripts/rank-source-files.py <repo> --limit <budget> --format list` and read that selection, highest first.

  Depth is a topological accident: it measures how deeply someone nested a folder, not how much the file matters. On a `packages/<pkg>/src/modules/<m>/service.ts` workspace every service sits at depth 5 and the whole layer disappears, while a top-level `tools/` folder survives intact — the fixture in `scripts/test-rank-source-files.sh` is exactly this shape, and a depth-4 cap there keeps 1 file of 6, the one worth nothing, and drops all five that carry the architecture. The ranker orders by how many distinct DIRECTORIES import a file (a file pulled in by 40 files from one folder is a local helper; one pulled in by 12 files from 9 folders is load-bearing), and reserves a quarter of the budget for entry points — routes, commands, job handlers — which nothing imports and which in-degree alone would bury, though they describe the system's surface better than any util.

  It resolves TypeScript / JavaScript and Python only, and drops a specifier it cannot resolve rather than guessing, so a file reached solely through DI or a string-keyed dynamic require ranks low. Under-counting is the intended direction: it demotes a file, it never invents importance. Where the stack is neither TS/JS nor Python the ranker returns everything at rank 0 — fall back to a breadth-first walk and say so in `walk_scope`, rather than pretending the order means something.
 This threshold is a **walk-strategy** trigger, not a disclosure trigger — the two used to be one sentence and conflating them was most of the bug. Disclosure is unconditional (Step 2.5 + check 7) at every repo size, because damage is proportional to `present − seen`, not to `present`: a 900-file repo whose `## Conventions` rests on 10 files per category is nowhere near 10k and is exactly where the caps bite hardest. Making the marker conditional would also make its *absence* ambiguous ("we read everything" vs "we sampled but you were under the threshold") — a signal whose absence carries no information is not a signal, and check 7 could not be mechanically enforced against one. Under this branch, record the selection method in `walk_scope` — `walk_scope: centrality-ranked, top <N> of <P> (hub share 0.75)` — so the sampled rows say *why* these files and not others. `[SAMPLED: <seen>/<present> <unit>]` is unchanged and still mandatory: a better sample is still a sample.
- **Repo without git** → skip Step 12 (recent activity). All other steps work. Step 2.5's census falls back to `find` + an explicit exclude list and records `census_method: find`; a `find` denominator is only ever comparable to another `find` denominator, never to a `git-ls-files` one.
- **Unrecognized stack** → still emit `## Stack` with raw findings ("manifests detected: X, Y") + ask user one consolidated question to confirm framework.
- **Extraction conflicts with prior `_extracted-codebase.md` (REFRESH)** → write the new one; emit `## Diff vs prior` section listing what changed (added/removed/changed). Phase 6 learning loop reads this diff.

## Quality bar

The output should let any downstream generator (pattern author, agent author, rule author) write project-specific content **without asking another question + without re-grepping the codebase**. If the generator still needs to look something up, this skill missed it.
